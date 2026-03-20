# awscli-simple-app-deploy
## リポジトリ概要
ビッグテックが提供するAPIコマンドやAPIモジュールを勉強しながら、基本的にCLIコマンドを使って本番環境に簡単なアプリをデプロイする。  
今回はAWSが提供するawscliを使って簡単なto-doアプリをデプロイする
- フルマネージド + サーバーレス + コンテナといったPaaS的な恩恵を受けながら、なるべくベンダーロックインしないであとで他のクラウドベンダーでも使用されそうなパターンを学んでいく
- CloudFormationやTerraform等のインフラ構築IaCは複雑になり、かつ、勉強のモチベーションがわかないので、あくまでベンダー提供のAPI(awscli)を気持ちよく学んでいく
- IAMユーザーとそのアクセスキーは作らないで、ブラウザからの時間制限付きRootユーザー認証によってCLIコマンドを走らせる仕様（よってこのプロジェクトは個人レベルの勉強用に留めてください）
- IAM Identity CenterのようなIDaaSはオーバーエンジニアリングになるので利用しない（ミイラ取りがミイラになる？）
- クラウドの仕組みとベンター提供のAPIシステムを理解したら、すぐに構築したインフラはぶち壊す（マネーを吸い取られないように）
- 「ビッグテックからは、フリーで提供される汎用的APIの仕組みを学んで盗んではすぐ逃げろ！」の精神を学ぶ
- 後で監視社会になったとき「あーケツに敷かれながらも、俺が学んだあのシステムがこういう風に今利用されているのだなあ。。。」と皮肉的にも後で感慨に浸れるように今勉強しておく（ささやかな反抗心）

## Todo App - AWS App Runner + RDS MySQL

シンプルなTo-DoアプリケーションをAWS App Runner + RDS MySQLで構築するプロジェクトです。  
**必要最低限のセキュリティなので、テスト用・勉強用のみとしてご使用ください。**

### コンポーネント

- **Frontend**: バニラJavaScript（S3の静的サイトホスティング機能有効化、CloudFront未実装）
- **Backend**: FastAPI（App Runner）
- **Database**: 
  - **開発環境**: SQLite（ローカルファイル）
  - **本番環境**: MySQL 8（RDS）

## 📋 前提条件

### ローカル開発
- uv
- node.js

## 🚀 クイックスタート

### ローカル開発環境

✅ **.envファイル不要**: 環境変数なしでそのまま動作  
✅ **SQLiteを自動使用**: MySQLのインストール不要  
✅ **最小限の依存関係**: 開発に必要なものだけ  
✅ **自動リロード**: コード変更時に自動で再起動  
✅ **ファイルベースDB**: `todo.db`に保存される

```bash
# 1. バックエンドの起動
cd backend

# 初回のみ
uv sync

uv run uvicorn main:app --reload --port 8080

# 2. フロントエンドの起動（別ターミナル）
cd frontend
npx serve -p 3000
```

**これだけです！** 環境変数なしで起動すると：
- ✅ 自動的にSQLiteモード（開発環境）
- ✅ `todo.db`ファイルが自動作成
- ✅ テーブルが自動作成

ブラウザで以下にアクセス：
- **フロントエンド**: http://localhost:3000
- **API**: http://localhost:8080
- **APIドキュメント**: http://localhost:8080/docs

### AWSへのデプロイ（本番環境）

### 前提条件
- 最低でも2FAを設定したRootアカウントをAWSに作っていること（以前作った簡単な[やり方](https://github.com/Shinya-GitHub-Center/awscli-docker/wiki/Step-1)のWiki）
- AWS CLI が[インストール](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)されていること（グローバル環境）
- `aws login`で適切なIAM権限を持ったアカウントでログインしていること（今回はRootアカウントでログインし、リージョンはap-northeast-1にする）
- ローカル開発環境にdockerがインストールされていること（今回はローカルマシンで作成したdockerイメージを手動でAWS ECRにプッシュする方法を採用）

**手順:**

- 注意： インフラ構築用の各スクリプトファイルで設定するプロジェクト名はすべて同じ名前にして、かつ、デフォルト値から変更することを推奨。すべてアルファベットの小文字のみで推測が難しい文字列を使用してください（データベース名決定時とバケット名決定時にエラーがでないようにするため）

1. **基本インフラと続いてRDS MySQL を作成**

```bash
./infrastructure/create-infra-mysql.sh
```

2. **Secrets Manager にDB認証情報を保存**

```bash
./infrastructure/create-secrets.sh
```

以下の情報を入力します：
- `DB_HOST`: RDSエンドポイント名（例: `your-rds-endpoint.region.rds.amazonaws.com`）
- `DB_USER`: `admin`（デフォルト）
- `DB_PASSWORD`: セキュアなパスワード
- `DB_NAME`: `${PRJ_NAME}db`（デフォルト）
- `DB_PORT`: `3306`（デフォルト）

3. **App Runner をデプロイ**

```bash
./infrastructure/create-app-runner.sh
```

- App Runnerサービス起動後、`frontend/app.js`のAPI_URLを更新する（固有に発行されたサービスURLに入れ替える、パスの部分はそのままでよい）
- `backend`内のコードを変更した場合は、再び`create-app-runner.sh`を実行するだけで新バージョンのバックエンドアプリで自動的にデプロイ・有効化される
- 本番環境に対する手動のマイグレーション作業は不要。なぜなら、App Runnerはサービスを作成すると即座にコンテナを起動し、かつ、アプリケーションも起動する。そのため管理人orユーザーがまだアプリケーションにアクセスしていない時点ですでに一回目のlifespan関数は実行されているため。

※ DB認証情報はApp Runnerが起動時にSecrets Managerから自動的に取得される。

4. **フロントエンドをS3にデプロイ**

```bash
./infrastructure/deploy-frontend-s3.sh
```

このスクリプトは以下を自動実行します：
- S3バケットの作成
- パブリックアクセスの設定
- 静的ウェブサイトホスティングの有効化
- フロントエンドファイルのアップロード（`.`で始まるファイルは除外）
- キャッシュ設定（ブラウザのみ、1時間）

`frontend`内のコードを変更した場合は、再び`deploy-frontend-s3.sh`を実行するだけで新バージョンのフロントエンドアプリで自動的にデプロイ・有効化される

#### Secrets Manager の操作コマンド

**シークレットを確認:**

```bash
aws secretsmanager get-secret-value --secret-id $SECRET_NAME --region $REGION
```

**シークレットを更新:**

```bash
./infrastructure/create-secrets.sh
```

既存のシークレットを上書き更新します。

**シークレットを削除:**

```bash
aws secretsmanager delete-secret \
  --secret-id $SECRET_NAME \
  --force-delete-without-recovery \
  --region $REGION
```

## 手動で簡単にデータベースの中に入る方法
AWSコンソールから該当データベースを選択後、接続とセキュリティからクラウドシェルを選択し起動、「myhappytodoapp-mysql-connect」のような一時的に作成されるVPC名を決定してデータベース内に接続する。

## 🔧 開発環境 vs 本番環境

### 環境の自動判定（以前作ったCloud Runで動くFlaskアプリとと同じ！）

このプロジェクトは**環境変数の有無で自動的に環境を判定**します：

- **開発環境**: `DB_HOST`と`DB_PASSWORD`が未設定の場合、自動的に開発モード（SQLite）で起動します。
- **本番環境**: `DB_HOST`と`DB_PASSWORD`が存在する場合（AWS Secrets Managerが環境変数を自動的に設定）は、MySQLが使用されます。

```python
# config.py（自動判定ロジック）
@property
def IS_PRODUCTION(self) -> bool:
    return bool(self.DB_HOST and self.DB_PASSWORD)

@property
def DATABASE_URL(self) -> str:
    if self.IS_PRODUCTION:
        return f"mysql+pymysql://..."  # MySQL
    else:
        return "sqlite:///./todo.db"   # SQLite
```

### Pydantic `Config` クラスの役割

**1. 環境変数の自動読み込み**

- Pydantic の `BaseSettings` は、`Config` クラスの設定に基づいて環境変数を自動的に読み込みます
- `Config` クラスがないと、環境変数が読み込まれず、常にデフォルト値（空文字列）が使用されます

**2. 本番環境での動作**

```bash
# App Runner が Secrets Manager から環境変数として注入
export DB_HOST="rds-endpoint.amazonaws.com"
export DB_PASSWORD="secure_password"

# ↓ Pydantic が自動的に環境変数を読み込む（Config クラスのおかげ）
settings = Settings()
print(settings.DB_HOST)  # "rds-endpoint.amazonaws.com"
```

**3. ローカル環境での柔軟性**

- `.env` ファイルがある場合: 自動的に読み込まれる
- `.env` ファイルがない場合: `config.py`にハードコードされたデフォルト値（空文字列）を使用 → SQLite モード

**4. AWS App Runner との統合**

本番環境では、App Runner が起動時に以下を実行：

```json
{
  "RuntimeEnvironmentSecrets": {
    "DB_HOST": "arn:aws:secretsmanager:...:DB_HOST::",
    "DB_PASSWORD": "arn:aws:secretsmanager:...:DB_PASSWORD::",
    ...
  }
}
```

→ Secrets Manager から取得した値が環境変数として設定される  
→ `Config` クラスにより Pydantic が自動的に読み込む  
→ `IS_PRODUCTION = True` となり MySQL が使用される

#### まとめ

`Config` クラスは一見使われていないように見えますが、**Pydantic の内部メカニズムで重要な役割**を果たしています。このクラスがないと：

- ❌ 環境変数が読み込まれない
- ❌ 本番環境で Secrets Manager の値が反映されない
- ❌ 常に SQLite モードで起動してしまう

## 📁 プロジェクト構造

このプロジェクトは**モノレポ（Monorepo）構成**を採用しています。

### モノレポ構成とは？

複数の独立したプロジェクト（バックエンド、フロントエンド、インフラ）を**1つのGitリポジトリ**で管理する方式です。

```
awscli-simple-app-deploy/              # 1つのGitリポジトリ
├── .git/                              # Gitリポジトリのルート
├── backend/                           # 独立したPythonプロジェクト
│   ├── routers/
│   │   ├── __init__.py
│   │   └── todos.py                  # APIエンドポイント
│   ├── Dockerfile                    # Dockerイメージ定義
│   ├── config.py                     # 設定管理（環境自動判定）
│   ├── database.py                   # データベース接続
│   ├── main.py                       # FastAPIアプリケーション
│   ├── models.py                     # SQLAlchemyモデル
│   ├── pyproject.toml                # Python依存関係管理（uv対応）
│   ├── requirements.txt              # 本番環境用依存関係（Docker用）
│   ├── schemas.py                    # Pydanticスキーマ
│   ├── todo.db                       # ローカル開発用SQLiteDB
│   └── uv.lock                       # uvロックファイル
├── frontend/                          # 独立した静的サイト
│   ├── app.js                        # JavaScriptロジック
│   ├── favicon.ico                   # ファビコン
│   ├── index.html                    # メインHTML
│   └── style.css                     # スタイル
├── infrastructure/                    # デプロイスクリプト
│   ├── cleanup.sh                    # リソース削除
│   ├── create-app-runner.sh          # App Runner作成
│   ├── create-infra-mysql.sh         # VPC/RDS作成
│   ├── create-secrets.sh             # Secrets Manager設定
│   └── deploy-frontend-s3.sh         # フロントエンドデプロイ
└── README.md                          # プロジェクト全体説明
```

### ディレクトリ構成の設計思想

#### 1. **backend/** - 独立したPythonプロジェクト

`pyproject.toml` と `.python-version` が `backend/` 内にある理由：

- ✅ バックエンドが完全に独立したPythonアプリ
- ✅ `backend/` ディレクトリだけを別プロジェクトにコピー可能
- ✅ フロントエンド/インフラとPython環境が混在しない
- ✅ 各部分の責任が明確

```bash
# バックエンドの開発
cd backend
uv sync                    # pyproject.toml から依存関係をインストール
uv run uvicorn main:app --reload
```

#### 2. **frontend/** - 独立した静的サイト

- バニラJavaScript（フレームワークなし）
- `package.json` 不要
- Python/Node.js の依存なし

```bash
# フロントエンドの開発
cd frontend
python3 -m http.server 3000
# または
npx serve -p 3000
```

#### 3. **infrastructure/** - デプロイスクリプト

- AWS CLI を使ったインフラ構築スクリプト
- RDS、App Runner、S3、Secrets Manager などを自動作成

#### 4. **.gitignore** - ルートに1つ

モノレポでは `.gitignore` はルートに1つ配置するのが標準：

- ✅ プロジェクト全体の無視パターンを一元管理
- ✅ メンテナンスが容易
- ✅ 重複を避ける

### 依存関係の管理

| ファイル | 用途 | 使用環境 |
|---------|------|---------|
| `backend/pyproject.toml` | 開発環境の依存関係 | ローカル（SQLite） |
| `backend/requirements.txt` | 本番環境の依存関係 | Docker/App Runner（MySQL） |

### なぜモノレポ？

**メリット:**
- ✅ フロントエンド、バックエンド、インフラを一緒に管理
- ✅ 1つのコミットで複数の変更を同期
- ✅ 統一されたCI/CD
- ✅ コードの再利用が容易

**このプロジェクトの特徴:**
- バックエンドとフロントエンドは完全に独立
- 各部分を別々にデプロイ可能
- 開発環境も独立して起動

## 📡 API エンドポイント

### Todo API

| メソッド | エンドポイント | 説明 |
|---------|--------------|------|
| GET | `/api/todos` | 全Todoを取得（ページネーション対応） |
| POST | `/api/todos` | 新しいTodoを作成 |
| DELETE | `/api/todos/{todo_id}` | Todoを削除 |
| PATCH | `/api/todos/{todo_id}/toggle` | 完了状態をトグル |

### ヘルスチェック

| メソッド | エンドポイント | 説明 |
|---------|--------------|------|
| GET | `/` | ルート |
| GET | `/health` | ヘルスチェック |

## 💰 コスト見積もり

### 開発環境（ローカル）

**完全無料** - SQLite + ローカルサーバー

### 本番環境（AWS）

| サービス | スペック | 月額 |
|---------|---------|------|
| RDS MySQL | db.t4g.micro (1vCPU, 1GB) | $12-15 |
| App Runner | 0.25 vCPU, 0.5 GB | $7-10 |
| S3 + CloudFront | 静的ホスティング | $0.50-2 |
| **合計** | | **$20-27** |

### コスト削減のヒント

- 開発時は RDS を停止（最大7日間）
- App Runner の自動スケーリングを活用
- 不要時は `cleanup.sh` でリソース削除

## 🧹 リソースの削除

```bash
cd infrastructure
./cleanup.sh
```

⚠️ **警告**: すべてのデータが削除されます。復元できません。

## 🔒 セキュリティ

### 実運用環境での推奨事項

1. **S3**: パブリックアクセスを無効化（デフォルト） - S3バケットをプライベートにした上で、エンドユーザーはすべてCloudFront経由でアクセスさせるようにする。
2. **セキュリティグループ**: MySQL接続用セキュリティグループのCIDRの値を現在の`0.0.0.0/0`からAppRunner（App Runner VPC Connector?）のものと同じにする
3. **CORS**: 特定のドメインのみ許可（本番環境のURLにあわせる）
4. **HTTPS**: CloudFront + ACM で SSL/TLS 証明書を設定