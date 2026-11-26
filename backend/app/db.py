"""SQLAlchemy engine, session factory, and declarative base."""

from __future__ import annotations

from collections.abc import Generator

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from .config import Settings, get_settings


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy ORM models."""


def create_engine_for_url(database_url: str) -> Engine:
    is_sqlite = database_url.startswith("sqlite")
    connect_args = {"check_same_thread": False} if is_sqlite else {}
    engine = create_engine(database_url, connect_args=connect_args, future=True)

    if is_sqlite:
        @event.listens_for(engine, "connect")
        def _set_sqlite_pragmas(dbapi_conn, _conn_record) -> None:
            cursor = dbapi_conn.cursor()
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.close()

    return engine


def create_session_factory(settings: Settings | None = None) -> tuple[Engine, sessionmaker[Session]]:
    cfg = settings or get_settings()
    engine = create_engine_for_url(cfg.resolved_database_url())
    factory = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)
    return engine, factory


_default_engine: Engine | None = None
_default_session_factory: sessionmaker[Session] | None = None


def init_db_factory(settings: Settings | None = None) -> sessionmaker[Session]:
    global _default_engine, _default_session_factory
    engine, factory = create_session_factory(settings)
    _default_engine = engine
    _default_session_factory = factory
    return factory


def get_session_factory() -> sessionmaker[Session]:
    if _default_session_factory is None:
        return init_db_factory()
    return _default_session_factory


def get_db() -> Generator[Session, None, None]:
    factory = get_session_factory()
    db = factory()
    try:
        yield db
    finally:
        db.close()
