#!/bin/bash

# 基本インフラおよびRDS MySQL インスタンスを作成するスクリプト

set -e

# 基本インフラ構築用設定変数
# プロジェクト名はデフォルト値から変更することを推奨
VPC_CIDR="10.77.0.0/16"
PRJ_NAME="myhappytodoapp"
SUBNET_1_CIDR="10.77.10.0/24"
SUBNET_2_CIDR="10.77.20.0/24"
REGION="ap-northeast-1"
AZ_1="a"
AZ_2="c"

# データベース用設定変数
DB_INSTANCE_IDENTIFIER="${PRJ_NAME}-mysql"
DB_NAME="${PRJ_NAME}db"
DB_USERNAME="admin"
DB_PASSWORD="00000000"
DB_INSTANCE_CLASS="db.t4g.micro"
ALLOCATED_STORAGE=20
ENGINE="mysql"
ENGINE_VERSION="8.4.7"
DB_SUBNET_GROUP_NAME="${PRJ_NAME}-db-subnet-group"

echo "🚀 基本インフラを作成します..."

# Create VPC and return VPC_ID
VPC_ID=$(aws ec2 create-vpc --cidr-block "${VPC_CIDR}" --query Vpc.VpcId --output text)
# Attach a tag to the created VPC
aws ec2 create-tags --resources "${VPC_ID}" --tags Key=Name,Value="${PRJ_NAME}-vpc"

# Create Subnet 1 and return SUBNET_ID_1
SUBNET_ID_1=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "${SUBNET_1_CIDR}" --availability-zone "${REGION}${AZ_1}" --query Subnet.SubnetId --output text)
# Attach a tag to the created Subnet 1
aws ec2 create-tags --resources "${SUBNET_ID_1}" --tags Key=Name,Value="${PRJ_NAME}-subnet-${REGION}${AZ_1}"

# Create Subnet 2 and return SUBNET_ID_2
SUBNET_ID_2=$(aws ec2 create-subnet --vpc-id "${VPC_ID}" --cidr-block "${SUBNET_2_CIDR}" --availability-zone "${REGION}${AZ_2}" --query Subnet.SubnetId --output text)
# Attach a tag to the created Subnet 2
aws ec2 create-tags --resources "${SUBNET_ID_2}" --tags Key=Name,Value="${PRJ_NAME}-subnet-${REGION}${AZ_2}"

# Create Security Group and return SG_ID
SG_ID=$(aws ec2 create-security-group --group-name "addtion" --description "For incoming App Runner connection over RDS" --vpc-id "$VPC_ID" --query GroupId --output text)
# Authorize Security Group Ingress
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 3306 --cidr 0.0.0.0/0 > /dev/null

# Create DB Subnet Group
aws rds create-db-subnet-group \
    --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" \
    --db-subnet-group-description "Subnet group for Todo App RDS" \
    --subnet-ids "${SUBNET_ID_1}" "${SUBNET_ID_2}" \
    --region "${REGION}" \
    --tags Key=Name,Value="${DB_SUBNET_GROUP_NAME}" > /dev/null

echo "🚀 基本インフラの作成完了！"

echo "🚀 RDS MySQL インスタンスを作成します..."

# RDS インスタンスの作成
echo "🗄️ RDSインスタンスを作成中..."
aws rds create-db-instance \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --db-instance-class $DB_INSTANCE_CLASS \
    --engine $ENGINE \
    --engine-version $ENGINE_VERSION \
    --master-username $DB_USERNAME \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage $ALLOCATED_STORAGE \
    --storage-type gp3 \
    --vpc-security-group-ids "$SG_ID" \
    --db-subnet-group-name "${DB_SUBNET_GROUP_NAME}" \
    --db-name $DB_NAME \
    --backup-retention-period 7 \
    --port 3306 \
    --no-publicly-accessible \
    --region $REGION \
    --tags Key=Project,Value=TodoApp Key=Environment,Value=Production > /dev/null

echo "⏳ RDSインスタンスの作成を待機中（5-10分かかります）..."
aws rds wait db-instance-available \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --region $REGION

# エンドポイント情報の取得
DB_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --query "DBInstances[0].Endpoint.Address" \
    --output text \
    --region $REGION)

echo ""
echo "✅ RDS MySQLインスタンスが作成されました！"
echo ""
echo "========================================="
echo "📊 接続情報"
echo "========================================="
echo "エンドポイント: $DB_ENDPOINT"
echo "ポート: 3306"
echo "データベース名: $DB_NAME"
echo "ユーザー名: $DB_USERNAME"
echo "パスワード: $DB_PASSWORD"
echo "========================================="
