from pydantic import BaseModel, Field, field_serializer
from datetime import datetime, timezone
from typing import Optional


class TodoBase(BaseModel):
    """Todo基本スキーマ"""

    title: str = Field(
        ..., min_length=1, max_length=255, description="タスクのタイトル"
    )
    description: Optional[str] = Field(
        None, max_length=1000, description="タスクの詳細説明"
    )
    completed: bool = Field(default=False, description="完了状態")


class TodoCreate(TodoBase):
    """Todo作成用スキーマ"""

    pass


class TodoUpdate(BaseModel):
    """Todo更新用スキーマ（部分更新対応）"""

    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = Field(None, max_length=1000)
    completed: Optional[bool] = None


class TodoResponse(TodoBase):
    """Todoレスポンススキーマ"""

    id: int
    created_at: datetime
    updated_at: datetime

    @field_serializer("created_at", "updated_at")
    def serialize_datetime(self, dt: datetime) -> str:
        """DatetimeをUTC ISO 8601形式にシリアライズ"""
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.isoformat()

    class Config:
        from_attributes = True
