"""Add a required course level without losing existing rows."""
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("courses", sa.Column("level", sa.Text(), nullable=True))
    op.execute("UPDATE courses SET level = CASE WHEN is_elective "
               "THEN 'beginner' ELSE 'intermediate' END")
    op.alter_column("courses", "level", existing_type=sa.Text(), nullable=False)


def downgrade() -> None:
    # Dropping the column also deletes any manually assigned levels.
    op.drop_column("courses", "level")
