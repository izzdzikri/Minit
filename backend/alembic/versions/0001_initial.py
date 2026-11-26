"""Initial schema: meetings, transcript_segments, upload_sessions.

Revision ID: 0001_initial
Revises:
Create Date: 2026-11-26 20:33:00
"""

from __future__ import annotations

import sqlalchemy as sa

from alembic import op

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "meetings",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("client_meeting_id", sa.String(length=128), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("language_hint", sa.String(length=16), nullable=False),
        sa.Column("glossary", sa.Text(), nullable=True),
        sa.Column("silence_ranges_json", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("progress_percent", sa.Integer(), nullable=False),
        sa.Column("status_message", sa.String(length=255), nullable=False),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("detected_language", sa.String(length=16), nullable=True),
        sa.Column("duration_sec", sa.Float(), nullable=True),
        sa.Column("audio_path", sa.String(length=512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("client_meeting_id"),
    )
    op.create_index(
        "ix_meetings_client_meeting_id",
        "meetings",
        ["client_meeting_id"],
        unique=True,
    )

    op.create_table(
        "transcript_segments",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("meeting_id", sa.String(length=36), nullable=False),
        sa.Column("speaker_label", sa.String(length=64), nullable=False),
        sa.Column("start_sec", sa.Float(), nullable=False),
        sa.Column("end_sec", sa.Float(), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("avg_logprob", sa.Float(), nullable=True),
        sa.Column("no_speech_prob", sa.Float(), nullable=True),
        sa.Column("is_loop_flagged", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["meeting_id"], ["meetings.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_transcript_segments_meeting_id",
        "transcript_segments",
        ["meeting_id"],
        unique=False,
    )

    op.create_table(
        "upload_sessions",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("meeting_id", sa.String(length=36), nullable=False),
        sa.Column("file_ext", sa.String(length=16), nullable=True),
        sa.Column("total_bytes", sa.BigInteger(), nullable=False),
        sa.Column("received_bytes", sa.BigInteger(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.ForeignKeyConstraint(["meeting_id"], ["meetings.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("meeting_id"),
    )


def downgrade() -> None:
    op.drop_table("upload_sessions")
    op.drop_index("ix_transcript_segments_meeting_id", table_name="transcript_segments")
    op.drop_table("transcript_segments")
    op.drop_index("ix_meetings_client_meeting_id", table_name="meetings")
    op.drop_table("meetings")
