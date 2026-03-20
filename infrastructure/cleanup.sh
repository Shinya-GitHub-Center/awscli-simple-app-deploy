#!/bin/bash

# 作成したAWSリソースをすべて削除するスクリプト

set -e

# あなたが作成したプロジェクト名に変更してください
PRJ_NAME="myhappytodoapp"
REGION="ap-northeast-1"

echo "========================================="
echo "🗑️  Todo App - リソース削除"
echo "========================================="
echo ""


# 確認
read -r -p "⚠️  警告: すべてのリソース（RDS、App Runner、S3）を削除します。
データは復元できません。本当に削除しますか？ (yes/no): " confirm

if [ "$confirm" != "yes" ] && [ "$confirm" != "y" ]; then
    echo "削除をキャンセルしました"
    exit 0
fi

echo ""
echo "1. App Runner サービスを削除中..."
SERVICE_ARN=$(aws apprunner list-services --region $REGION \
    --query "ServiceSummaryList[?ServiceName=='${PRJ_NAME}-backend'].ServiceArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$SERVICE_ARN" ]; then
    aws apprunner delete-service --service-arn "$SERVICE_ARN" --region $REGION > /dev/null
    echo "✅ App Runnerサービス削除完了"
    echo "⏳ サービス削除の完了を待機中（30秒）..."
    sleep 30
else
    echo "⏭️  App Runnerサービスが見つかりません"
fi

# VPC Connectorの削除
echo "🔌 VPC Connectorを削除中..."
VPC_CONNECTOR_ARN=$(aws apprunner list-vpc-connectors \
    --region $REGION \
    --query "VpcConnectors[?VpcConnectorName=='${PRJ_NAME}-vpc-connector'].VpcConnectorArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$VPC_CONNECTOR_ARN" ] && [ "$VPC_CONNECTOR_ARN" != "None" ]; then
    aws apprunner delete-vpc-connector \
        --vpc-connector-arn "$VPC_CONNECTOR_ARN" \
        --region $REGION >/dev/null 2>&1 && \
        echo "✅ VPC Connector削除完了" || \
        echo "⚠️  VPC Connectorの削除に失敗"
else
    echo "⏭️  VPC Connectorが見つかりません"
fi

echo ""
echo "2. ECR リポジトリを削除中..."
aws ecr delete-repository \
    --repository-name ${PRJ_NAME} \
    --force \
    --region $REGION >/dev/null 2>&1 || echo "⏭️  ECRリポジトリが見つかりません"

echo ""
echo "3. RDS インスタンスを削除中..."
aws rds delete-db-instance \
    --db-instance-identifier ${PRJ_NAME}-mysql \
    --skip-final-snapshot \
    --region $REGION >/dev/null 2>&1 || echo "⏭️  RDSインスタンスが見つかりません"

echo ""
echo "4. S3 バケットを削除中..."
BUCKET_NAME=$(aws s3 ls | grep ${PRJ_NAME}-frontend | awk '{print $3}' | head -1)

if [ -n "$BUCKET_NAME" ]; then
    aws s3 rm s3://"$BUCKET_NAME" --recursive > /dev/null
    aws s3api delete-bucket --bucket "$BUCKET_NAME" --region $REGION > /dev/null
    echo "✅ S3バケット削除完了"
else
    echo "⏭️  S3バケットが見つかりません"
fi

echo ""
echo "5. Secrets Manager のシークレットを削除中..."
aws secretsmanager delete-secret \
    --secret-id ${PRJ_NAME}/db-credentials \
    --force-delete-without-recovery \
    --region $REGION >/dev/null 2>&1 || echo "⏭️  シークレットが見つかりません"

echo ""
echo "6. IAMロールを削除中..."
# インスタンスロールのポリシーを削除
aws iam delete-role-policy \
    --role-name ${PRJ_NAME}-AppRunnerInstanceRole \
    --policy-name SecretsManagerAccess 2>/dev/null || true

aws iam delete-role \
    --role-name ${PRJ_NAME}-AppRunnerInstanceRole 2>/dev/null || echo "⏭️  ${PRJ_NAME}-AppRunnerInstanceRoleが見つかりません"

aws iam detach-role-policy \
    --role-name ${PRJ_NAME}-AppRunnerECRAccessRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess 2>/dev/null || true

aws iam delete-role \
    --role-name ${PRJ_NAME}-AppRunnerECRAccessRole 2>/dev/null || echo "⏭️  ${PRJ_NAME}-AppRunnerECRAccessRoleが見つかりません"

echo ""
echo "7. DBサブネットグループを削除中（RDSインスタンス削除完了まで待機）..."
echo "RDSインスタンスの削除を待機しています（数分かかる場合があります）..."
aws rds wait db-instance-deleted \
    --db-instance-identifier ${PRJ_NAME}-mysql \
    --region $REGION 2>/dev/null || true

aws rds delete-db-subnet-group \
    --db-subnet-group-name ${PRJ_NAME}-db-subnet-group \
    --region $REGION 2>/dev/null && echo "✅ DBサブネットグループ削除完了" || echo "⏭️  DBサブネットグループが見つかりません"

echo ""
echo "8. VPC関連リソースを削除中..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${PRJ_NAME}-vpc" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo "VPC ID: $VPC_ID"

    # 1. App Runner接続用のセキュリティグループ（addtion）を削除
    echo "  - App Runner接続用セキュリティグループ（addtion）を削除中..."
    ADDTION_SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=addtion" \
        --query "SecurityGroups[0].GroupId" \
        --output text \
        --region $REGION 2>/dev/null || echo "")

    if [ -n "$ADDTION_SG_ID" ] && [ "$ADDTION_SG_ID" != "None" ]; then
        aws ec2 delete-security-group --group-id "$ADDTION_SG_ID" --region $REGION >/dev/null 2>&1 && \
            echo "    ✅ App Runner接続用セキュリティグループ削除完了" || \
            echo "    ⚠️  セキュリティグループの削除に失敗: $ADDTION_SG_ID"
    else
        echo "    ⏭️  App Runner接続用セキュリティグループが見つかりません"
    fi

    # 2. サブネットを削除
    echo "  - サブネットを削除中..."
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query "Subnets[*].SubnetId" \
        --output text \
        --region $REGION 2>/dev/null || echo "")

    if [ -n "$SUBNET_IDS" ]; then
        for SUBNET_ID in $SUBNET_IDS; do
            aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --region $REGION 2>/dev/null && \
                echo "    ✅ サブネット削除完了: $SUBNET_ID" || \
                echo "    ⚠️  サブネットの削除に失敗: $SUBNET_ID"
        done
    else
        echo "    ⏭️  サブネットが見つかりません"
    fi

    # 3. VPCを削除
    echo "  - VPCを削除中..."
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region $REGION 2>/dev/null && \
        echo "    ✅ VPC削除完了" || \
        echo "    ⚠️  VPCの削除に失敗（手動で削除してください）: $VPC_ID"
else
    echo "⏭️  VPCが見つかりません"
fi

echo ""
echo "========================================="
echo "✅ 削除完了"
echo "========================================="
echo ""
echo "以下は手動で確認してください:"
echo "1. RDSスナップショット（ある場合）"
echo "2. CloudWatch Logs（App Runnerのログ）"
echo "3. VPCに関連するリソース（削除できなかった場合）"
echo ""
