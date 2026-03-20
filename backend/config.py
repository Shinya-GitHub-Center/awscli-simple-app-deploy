from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    # ========== 環境判定 ==========
    # ローカル開発環境では.envファイルがない場合以下のデフォルト値が使用される
    # 本番環境では必ずDB_HOSTとDB_PASSWORDが設定される想定
    # 本番環境ではAWS Secrets Managerに設定された値で上書きされる
    DB_HOST: str = ""
    DB_USER: str = "admin"
    DB_PASSWORD: str = ""
    DB_PORT: int = 3306
    DB_NAME: str = "tododb"

    # CORS設定（すべてのオリジンを許可 - リモート環境でも今回はテスト用）
    # 本番運用では特定のオリジンを許可するようにする
    CORS_ORIGINS: List[str] = ["*"]

    # デバッグモード（開発環境のみ有効）
    DEBUG: bool = False

    @property
    def IS_PRODUCTION(self) -> bool:
        """DB_HOSTとDB_PASSWORDの有無で本番環境を判定"""
        return bool(self.DB_HOST and self.DB_PASSWORD)

    @property
    def DATABASE_URL(self) -> str:
        """環境に応じたデータベースURLを自動で返す"""
        if self.IS_PRODUCTION:
            # 本番環境: MySQL（DB_HOSTが設定されている場合）
            return f"mysql+pymysql://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        else:
            # 開発環境: SQLite（DB_HOSTが未設定の場合は自動的にSQLite）
            return "sqlite:///./todo.db"

    @property
    def DATABASE_ECHO(self) -> bool:
        """開発環境でのみSQLログを出力"""
        return not self.IS_PRODUCTION and self.DEBUG

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        # 本番環境でSecrets Managerから注入される環境変数を正しく認識
        case_sensitive = True
        # 余分な環境変数（AWS App Runnerが自動設定するもの）を無視
        extra = "ignore"


settings = Settings()
