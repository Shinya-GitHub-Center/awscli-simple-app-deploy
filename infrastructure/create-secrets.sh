#!/bin/bash

# AWS Secrets Managerにシークレットを保存するスクリプト

set -e

echo "========================================="
echo "🔐 AWS Secrets Managerにシークレットを保存"
echo "========================================="
echo ""

PRJ_NAME="myhappytodoapp"
REGION="ap-northeast-1"
SECRET_NAME="${PRJ_NAME}/db-credentials"

# データベース接続情報（create-infra-mysql.shと合わせる）
# DB_HOST名は、リソース作成時に同じDB識別子を使用する限り、毎回エンドポイントの文字列も同じになる
DB_HOST=""  # RDSエンドポイント名（create-infra-mysql.sh実行後に設定）
DB_USERNAME="admin"
DB_PASSWORD="00000000"
DB_NAME="${PRJ_NAME}db"
DB_PORT="3306"

# DB_HOSTが未設定の場合はエラー
if [ -z "$DB_HOST" ]; then
    echo "❌ エラー: DB_HOSTが設定されていません"
    echo ""
    echo "create-infra-mysql.shを実行後、出力されたエンドポイントをこのスクリプトのDB_HOSTに設定してください"
    echo ""
    exit 1
fi

echo "設定内容:"
echo "  DB_HOST: $DB_HOST"
echo "  DB_USER: $DB_USERNAME"
echo "  DB_PASSWORD: $DB_PASSWORD"
echo "  DB_NAME: $DB_NAME"
echo "  DB_PORT: $DB_PORT"
echo ""

# Secrets Managerにシークレットを作成（JSON形式）
echo "🔐 Secrets Managerにシークレットを保存中..."

SECRET_STRING=$(cat <<EOF
{
  "DB_HOST": "$DB_HOST",
  "DB_USER": "$DB_USERNAME",
  "DB_PASSWORD": "$DB_PASSWORD",
  "DB_NAME": "$DB_NAME",
  "DB_PORT": "$DB_PORT"
}
EOF
)

# 既存のシークレットを確認
SECRET_ARN=$(aws secretsmanager describe-secret \
    --secret-id $SECRET_NAME \
    --region $REGION \
    --query "ARN" \
    --output text 2>/dev/null || echo "None")

if [ "$SECRET_ARN" = "None" ]; then
    # 新規作成
    SECRET_ARN=$(aws secretsmanager create-secret \
        --name $SECRET_NAME \
        --description "Todo App Database Credentials" \
        --secret-string "$SECRET_STRING" \
        --region $REGION \
        --tags Key=Project,Value=TodoApp Key=Environment,Value=Production \
        --query "ARN" \
        --output text)

    echo "✅ シークレットを作成しました"
else
    # 既存のシークレットを更新
    aws secretsmanager put-secret-value \
        --secret-id $SECRET_NAME \
        --secret-string "$SECRET_STRING" \
        --region $REGION > /dev/null

    echo "✅ 既存のシークレットを更新しました"
fi

echo ""
echo "========================================="
echo "✅ 完了"
echo "========================================="
echo ""
echo "シークレット情報:"
echo "  名前: $SECRET_NAME"
echo "  ARN: $SECRET_ARN"
echo "  リージョン: $REGION"
echo ""
echo "次のステップ:"
echo "  ./create-app-runner.sh を実行してApp Runnerをデプロイ"
echo ""
echo "⚠️  シークレットの確認:"
echo "  aws secretsmanager get-secret-value --secret-id $SECRET_NAME --region $REGION"
echo ""
