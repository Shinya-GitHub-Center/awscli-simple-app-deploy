from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base
from routers import todos
from config import settings


# 起動時に毎回行われる処理
# lifespan関数のパラメータのappは使わないので、_appとしている
# この時点でtodosがインポートされているのでmodelsはBaseに自動登録されている
@asynccontextmanager
async def lifespan(_app: FastAPI):
    # 起動時の処理（ここでデータベース初期化とテーブル作成を行う）
    # 2回目以降の起動時はテーブルがすでに作成されているのでテーブル作成スキップ
    Base.metadata.create_all(bind=engine)

    if settings.IS_PRODUCTION:
        print("✅ Running in PRODUCTION mode (MySQL)")
    else:
        print("✅ Running in DEVELOPMENT mode (SQLite)")
        print(f"📁 Database file: todo.db")

    print("✅ Database tables created/verified")

    # アプリケーション実行中はyieldでブロックされる
    yield

    # シャットダウン時の処理（必要に応じて追加）


# FastAPIアプリケーションインスタンス
app = FastAPI(
    title="Todo API",
    description="シンプルなTo-DoアプリのAPI",
    version="1.0.0",
    debug=settings.DEBUG,
    lifespan=lifespan,
    # redirect_slashes=False,
)

# CORS設定（フロントエンドからのアクセスを許可）
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    # expose_headers=["*"],
)


# ルーター登録
app.include_router(todos.router, prefix="/api/todos", tags=["todos"])


# ヘルスチェック
@app.get("/")
def root():
    return {
        "message": "Todo API is running",
        "status": "healthy",
        "version": "1.0.0",
        "environment": "production" if settings.IS_PRODUCTION else "development",
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "database": "mysql" if settings.IS_PRODUCTION else "sqlite",
    }
