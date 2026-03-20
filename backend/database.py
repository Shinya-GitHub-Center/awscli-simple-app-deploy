from sqlalchemy.orm.session import Session
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from config import settings

# エンジン設定（SQLiteとMySQLで異なる設定を適用）
engine_kwargs = {
    "echo": settings.DATABASE_ECHO,
}

# 本番環境（MySQL）の場合のみプール設定を追加
if settings.IS_PRODUCTION:
    engine_kwargs.update(
        {
            "pool_pre_ping": True,  # 接続の有効性を確認
            "pool_recycle": 3600,  # 1時間ごとに接続をリサイクル
        }
    )
else:
    # 開発環境（SQLite）の場合
    engine_kwargs.update({"connect_args": {"check_same_thread": False}})

# データベースエンジン作成
engine = create_engine(settings.DATABASE_URL, **engine_kwargs)

# セッション作成
SessionLocal = sessionmaker[Session](autocommit=False, autoflush=False, bind=engine)

# ベースクラス
Base = declarative_base()


# 依存性注入用のDB接続関数
# todos APIからのリクエスト開始時に作成されレスポンス返却後に破棄（ライフサイクル管理）
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
