#!/bin/bash

# App Runner サービスを作成するスクリプト
# AWS Secrets Manager を使用してDB認証情報を管理

set -e

# 設定変数
PRJ_NAME="myhappytodoapp"
SERVICE_NAME="${PRJ_NAME}-backend"
REGION="ap-northeast-1"
ECR_REPO_NAME="${PRJ_NAME}"
SECRET_NAME="${PRJ_NAME}/db-credentials"

# スクリプトのディレクトリとプロジェクトルートを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 App Runner サービスを作成します..."
echo "📁 プロジェクトルート: $PROJECT_ROOT"

# Secrets Managerからシークレットを取得してチェック
echo "🔐 Secrets Managerからシークレットを確認中..."
SECRET_ARN=$(aws secretsmanager describe-secret \
    --secret-id $SECRET_NAME \
    --region $REGION \
    --query "ARN" \
    --output text 2>/dev/null || echo "None")

if [ "$SECRET_ARN" = "None" ]; then
    echo "❌ エラー: Secrets Managerにシークレットが見つかりません"
    echo ""
    echo "まず以下のスクリプトを実行してシークレットを作成してください:"
    echo "  ./create-secrets.sh"
    echo ""
    exit 1
fi

echo "✅ シークレット確認: $SECRET_ARN"

# ECRリポジトリの作成
echo "📦 ECRリポジトリを作成中..."
ECR_URI=$(aws ecr describe-repositories \
    --repository-names $ECR_REPO_NAME \
    --region $REGION \
    --query "repositories[0].repositoryUri" \
    --output text 2>/dev/null || echo "None")

if [ "$ECR_URI" = "None" ]; then
    aws ecr create-repository \
        --repository-name $ECR_REPO_NAME \
        --region $REGION > /dev/null

    ECR_URI=$(aws ecr describe-repositories \
        --repository-names $ECR_REPO_NAME \
        --region $REGION \
        --query "repositories[0].repositoryUri" \
        --output text)

    echo "✅ ECRリポジトリ作成完了: $ECR_URI"
else
    echo "✅ 既存のECRリポジトリを使用: $ECR_URI"
fi

# Docker イメージのビルドとプッシュ
echo "🐳 Dockerイメージをビルド中..."
cd "$PROJECT_ROOT/backend"

# ECRにログイン
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "$ECR_URI"

# イメージをビルド
docker build -t $ECR_REPO_NAME:latest .

# タグ付け（同じイメージに別の名前のエイリアスを付ける）
# ECRへのプッシュには完全なURIが必要なため
docker tag $ECR_REPO_NAME:latest "$ECR_URI":latest

# プッシュ
echo "📤 ECRにイメージをプッシュ中..."
docker push "$ECR_URI":latest

echo "✅ Dockerイメージのプッシュ完了"

cd ../infrastructure

# App Runner IAMロールの作成（ECRアクセス用）
echo "🔐 App Runner IAMロール（ECRアクセス）を作成中..."
ACCESS_ROLE_NAME="${PRJ_NAME}-AppRunnerECRAccessRole"

ACCESS_ROLE_ARN=$(aws iam get-role \
    --role-name $ACCESS_ROLE_NAME \
    --query "Role.Arn" \
    --output text 2>/dev/null || echo "None")

if [ "$ACCESS_ROLE_ARN" = "None" ]; then
    # 信頼ポリシー
    cat > /tmp/access-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "build.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    aws iam create-role \
        --role-name $ACCESS_ROLE_NAME \
        --assume-role-policy-document file:///tmp/access-trust-policy.json > /dev/null

    aws iam attach-role-policy \
        --role-name $ACCESS_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess

    ACCESS_ROLE_ARN=$(aws iam get-role \
        --role-name $ACCESS_ROLE_NAME \
        --query "Role.Arn" \
        --output text)

    echo "✅ ECRアクセスロール作成完了: $ACCESS_ROLE_ARN"
else
    echo "✅ 既存のECRアクセスロールを使用: $ACCESS_ROLE_ARN"
fi

# App Runner インスタンスロールの作成（Secrets Manager アクセス用）
echo "🔐 App Runner インスタンスロール（Secrets Manager）を作成中..."
INSTANCE_ROLE_NAME="${PRJ_NAME}-AppRunnerInstanceRole"

INSTANCE_ROLE_ARN=$(aws iam get-role \
    --role-name $INSTANCE_ROLE_NAME \
    --query "Role.Arn" \
    --output text 2>/dev/null || echo "None")

if [ "$INSTANCE_ROLE_ARN" = "None" ]; then
    # インスタンスロールの信頼ポリシー
    cat > /tmp/instance-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "tasks.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # Secrets Manager アクセスポリシー
    cat > /tmp/secrets-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "$SECRET_ARN"
    }
  ]
}
EOF

    # インスタンスロールを作成
    aws iam create-role \
        --role-name $INSTANCE_ROLE_NAME \
        --assume-role-policy-document file:///tmp/instance-trust-policy.json > /dev/null

    # Secrets Managerポリシーをアタッチ
    aws iam put-role-policy \
        --role-name $INSTANCE_ROLE_NAME \
        --policy-name SecretsManagerAccess \
        --policy-document file:///tmp/secrets-policy.json

    INSTANCE_ROLE_ARN=$(aws iam get-role \
        --role-name $INSTANCE_ROLE_NAME \
        --query "Role.Arn" \
        --output text)

    echo "✅ インスタンスロール作成完了: $INSTANCE_ROLE_ARN"
    echo "⏳ ロールの伝播を待機中（10秒）..."
    sleep 10
else
    echo "✅ 既存のインスタンスロールを使用: $INSTANCE_ROLE_ARN"
fi

# Secrets Managerからシークレットの詳細を取得して確認
echo "🔐 Secrets Managerからシークレットキーを取得中..."
aws secretsmanager get-secret-value \
    --secret-id $SECRET_NAME \
    --region $REGION \
    --query "SecretString" \
    --output text | jq -r 'keys[]' > /dev/null

# VPC情報の取得
echo "🌐 VPC情報を取得中..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${PRJ_NAME}-vpc" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region $REGION)

# サブネットの取得（VPC内のすべてのサブネット）
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[*].SubnetId" \
    --output text \
    --region $REGION)

# セキュリティグループの取得
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=addtion" \
    --query "SecurityGroups[0].GroupId" \
    --output text \
    --region $REGION)

echo "  VPC ID: $VPC_ID"
echo "  サブネット: $SUBNET_IDS"
echo "  セキュリティグループ: $SG_ID"

# VPC Connectorの作成
echo "🔌 App Runner VPC Connectorを作成中..."
VPC_CONNECTOR_NAME="${PRJ_NAME}-vpc-connector"

# 既存のVPC Connectorを確認
VPC_CONNECTOR_ARN=$(aws apprunner list-vpc-connectors \
    --region $REGION \
    --query "VpcConnectors[?VpcConnectorName=='$VPC_CONNECTOR_NAME'].VpcConnectorArn" \
    --output text 2>/dev/null || echo "")

if [ -z "$VPC_CONNECTOR_ARN" ] || [ "$VPC_CONNECTOR_ARN" = "None" ]; then
    # SUBNET_IDSの値をスペースで区切って渡すため引用符は意図的になしにしている
    # shellcheck disable=SC2086
    VPC_CONNECTOR_ARN=$(aws apprunner create-vpc-connector \
        --vpc-connector-name "$VPC_CONNECTOR_NAME" \
        --subnets $SUBNET_IDS \
        --security-groups "$SG_ID" \
        --region $REGION \
        --query "VpcConnector.VpcConnectorArn" \
        --output text)

    echo "✅ VPC Connector作成完了: $VPC_CONNECTOR_ARN"
    echo "⏳ VPC Connectorの準備を待機中（30秒）..."
    sleep 30
else
    echo "✅ 既存のVPC Connectorを使用: $VPC_CONNECTOR_ARN"
fi

# App Runner 設定ファイルの作成（Secrets参照とVPC接続を使用）
cat > /tmp/apprunner-config.json << EOF
{
  "ServiceName": "$SERVICE_NAME",
  "SourceConfiguration": {
    "ImageRepository": {
      "ImageIdentifier": "$ECR_URI:latest",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "8080",
        "RuntimeEnvironmentSecrets": {
          "DB_HOST": "$SECRET_ARN:DB_HOST::",
          "DB_USER": "$SECRET_ARN:DB_USER::",
          "DB_PASSWORD": "$SECRET_ARN:DB_PASSWORD::",
          "DB_NAME": "$SECRET_ARN:DB_NAME::",
          "DB_PORT": "$SECRET_ARN:DB_PORT::"
        },
        "RuntimeEnvironmentVariables": {
          "CORS_ORIGINS": "[\"*\"]"
        }
      }
    },
    "AuthenticationConfiguration": {
      "AccessRoleArn": "$ACCESS_ROLE_ARN"
    }
  },
  "InstanceConfiguration": {
    "Cpu": "1 vCPU",
    "Memory": "2 GB",
    "InstanceRoleArn": "$INSTANCE_ROLE_ARN"
  },
  "NetworkConfiguration": {
    "EgressConfiguration": {
      "EgressType": "VPC",
      "VpcConnectorArn": "$VPC_CONNECTOR_ARN"
    }
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/health",
    "Interval": 10,
    "Timeout": 5,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  },
  "Tags": [
    {
      "Key": "Project",
      "Value": "TodoApp"
    },
    {
      "Key": "Environment",
      "Value": "Production"
    }
  ]
}
EOF

# 既存のApp Runnerサービスを確認
echo "🔍 既存のApp Runnerサービスを確認中..."
EXISTING_SERVICE_ARN=$(aws apprunner list-services \
    --region $REGION \
    --query "ServiceSummaryList[?ServiceName=='$SERVICE_NAME'].ServiceArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_SERVICE_ARN" ] && [ "$EXISTING_SERVICE_ARN" != "None" ]; then
    echo "📝 既存のサービスが見つかりました: $SERVICE_NAME"
    echo "🚀 新しいイメージをデプロイ中..."

    # start-deploymentのみで最新のECRイメージをデプロイ
    SERVICE_ARN="$EXISTING_SERVICE_ARN"
    aws apprunner start-deployment \
        --service-arn "$SERVICE_ARN" \
        --region $REGION >/dev/null 2>&1

    echo "⏳ デプロイメントの完了を待機中（約3分）..."
    sleep 180
else
    echo "🆕 新規サービスを作成します..."

    # App Runner サービスの作成
    SERVICE_ARN=$(aws apprunner create-service \
        --cli-input-json file:///tmp/apprunner-config.json \
        --region $REGION \
        --query "Service.ServiceArn" \
        --output text)

    echo "⏳ App Runnerサービスの起動を待機中（約5分）..."
    sleep 300
fi

# サービスURLの取得
SERVICE_URL=$(aws apprunner describe-service \
    --service-arn "$SERVICE_ARN" \
    --region $REGION \
    --query "Service.ServiceUrl" \
    --output text)

echo ""
echo "✅ App Runnerサービスが作成されました！"
echo ""
echo "========================================="
echo "🌐 サービス情報"
echo "========================================="
echo "サービス名: $SERVICE_NAME"
echo "サービスURL: https://$SERVICE_URL"
echo "API エンドポイント: https://$SERVICE_URL/api/todos"
echo "ヘルスチェック: https://$SERVICE_URL/health"
echo "========================================="
echo ""
echo "🔐 セキュリティ情報:"
echo "  Secrets Manager: $SECRET_NAME"
echo "  DB認証情報はSecrets Managerから自動取得されます"
echo ""
echo "次のステップ:"
echo "1. ブラウザで https://$SERVICE_URL にアクセス"
echo "2. frontend/app.js のAPI_URLを更新"
echo "3. フロントエンドをデプロイ"
echo ""

# クリーンアップ
rm -f /tmp/access-trust-policy.json /tmp/instance-trust-policy.json /tmp/secrets-policy.json /tmp/apprunner-config.json
