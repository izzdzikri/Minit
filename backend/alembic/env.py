"""Alembic migration environment reading DATABASE_URL from Settings."""

from __future__ import annotations

from logging.config import fileConfig

from sqlalchemy import pool

from alembic import context
from app import models  # noqa: F401  # Register ORM tables on Base.metadata.
from app.config import get_settings
from app.db import Base, create_engine_for_url

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _database_url() -> str:
    override = config.get_main_option("sqlalchemy.url")
    if override:
        return override
    return get_settings().resolved_database_url()


def run_migrations_offline() -> None:
    url = _database_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=url.startswith("sqlite"),
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    url = _database_url()
    connectable = create_engine_for_url(url)
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            render_as_batch=url.startswith("sqlite"),
        )
        with context.begin_transaction():
            context.run_migrations()
    if hasattr(pool, "NullPool"):
        connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
