from datetime import datetime
from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.sql import func
from database import Base


class Todo(Base):
    """Todoモデル"""

    __tablename__ = "todos"

    id = Column[int](Integer, primary_key=True, index=True, autoincrement=True)
    title = Column[str](String(255), nullable=False, index=True)
    description = Column[str](String(1000), nullable=True)
    completed = Column[bool](Boolean, default=False, nullable=False)
    created_at = Column[datetime](
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column[datetime](
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    def __repr__(self):
        return f"<Todo(id={self.id}, title='{self.title}', completed={self.completed})>"
