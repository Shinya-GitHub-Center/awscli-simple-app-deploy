#!/bin/bash

# フロントエンドをS3 + CloudFrontにデプロイするスクリプト

set -e

# 設定変数
PRJ_NAME="myhappytodoapp"
BUCKET_NAME="${PRJ_NAME}-frontend"
REGION="ap-northeast-1"

# スクリプトのディレクトリとプロジェクトルートを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🚀 フロントエンドをS3にデプロイします..."

# S3バケットの作成
echo "📦 S3バケットを作成中..."
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION >/dev/null 2>&1 || echo "バケット既存または作成済み"

# パブリックアクセス設定
echo "🔓 パブリックアクセスを設定中..."
aws s3api put-public-access-block \
    --bucket $BUCKET_NAME \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# バケットポリシーの設定
cat > /tmp/bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
    --bucket $BUCKET_NAME \
    --policy file:///tmp/bucket-policy.json

# 静的ウェブサイトホスティングを有効化
echo "🌐 静的ウェブサイトホスティングを有効化中..."
aws s3 website s3://$BUCKET_NAME/ \
    --index-document index.html \
    --error-document index.html

# フロントエンドファイルをアップロード
echo "📤 フロントエンドファイルをアップロード中..."
aws s3 sync "$PROJECT_ROOT/frontend/" s3://$BUCKET_NAME/ \
    --exclude ".*" \
    --cache-control "private, max-age=3600"

# ウェブサイトURLの取得
WEBSITE_URL="http://$BUCKET_NAME.s3-website-$REGION.amazonaws.com"

echo ""
echo "✅ フロントエンドのデプロイが完了しました！"
echo ""
echo "========================================="
echo "🌐 アクセス情報"
echo "========================================="
echo "S3 バケット: $BUCKET_NAME"
echo "ウェブサイトURL: $WEBSITE_URL"
echo "========================================="
echo ""
echo "⚠️  注意:"
echo ""
echo "CloudFrontを使用する場合は、CloudFrontディストリビューションを作成してください"
echo ""

# クリーンアップ
rm -f /tmp/bucket-policy.json
