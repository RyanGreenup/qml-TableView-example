import os
from typing import Any

import polars as pl
import psycopg2
from dotenv import load_dotenv
from PySide6.QtCore import QAbstractTableModel, QModelIndex, QPersistentModelIndex, Qt, Slot

DisplayRole = Qt.ItemDataRole.DisplayRole
EditRole = Qt.ItemDataRole.EditRole


class PostgresTableModel(QAbstractTableModel):
    """PostgreSQL-backed table model using Polars for data manipulation."""

    def __init__(self, parent: Any = None):
        super().__init__(parent)

        # Load environment variables
        load_dotenv()

        # Polars DataFrame to hold data
        self._df: pl.DataFrame = pl.DataFrame()

        # Sorting state
        self._sort_column: int = -1
        self._sort_order: Qt.SortOrder = Qt.SortOrder.AscendingOrder

        # Load data from PostgreSQL
        self._load_from_postgres()

    def _load_from_postgres(self) -> None:
        """Load data from PostgreSQL into Polars DataFrame."""
        # Build connection string
        host = os.getenv("PGHOST", "localhost")
        port = os.getenv("PGPORT", "5432")
        user = os.getenv("PGUSER", "postgres")
        password = os.getenv("PGPASSWORD", "")
        database = os.getenv("PGDATABASE", "postgres")

        query = "SELECT * FROM field_ops.tasks ORDER BY task_date DESC LIMIT 1000"

        # Connect and fetch data
        with psycopg2.connect(
            host=host, port=port, user=user, password=password, database=database
        ) as conn:
            with conn.cursor() as cur:
                cur.execute(query)
                assert cur.description is not None
                columns = [desc[0] for desc in cur.description]
                rows = cur.fetchall()

        # Convert to Polars DataFrame
        self._df = pl.DataFrame(rows, schema=columns, orient="row")
        print(f"[POSTGRES MODEL]: Loaded {len(self._df)} rows, {len(self._df.columns)} columns")

    # ========================================================================
    # REQUIRED METHODS
    # ========================================================================

    def rowCount(self, parent: QModelIndex | QPersistentModelIndex = QModelIndex()) -> int:
        """Return number of rows."""
        if parent.isValid():
            return 0
        return len(self._df)

    def columnCount(self, parent: QModelIndex | QPersistentModelIndex = QModelIndex()) -> int:
        """Return number of columns."""
        if parent.isValid():
            return 0
        return len(self._df.columns)

    def data(self, index: QModelIndex | QPersistentModelIndex, role: int = DisplayRole) -> str | None:
        """Return cell data."""
        role_enum = Qt.ItemDataRole(role)

        if not index.isValid():
            return None

        if not (0 <= index.row() < len(self._df) and 0 <= index.column() < len(self._df.columns)):
            return None

        if role_enum in (DisplayRole, EditRole):
            value = self._df.row(index.row())[index.column()]
            return str(value) if value is not None else ""

        return None

    def setData(self, index: QModelIndex | QPersistentModelIndex, value: Any, role: int = EditRole) -> bool:
        """Update cell data in DataFrame."""
        role_enum = Qt.ItemDataRole(role)

        if not index.isValid():
            return False

        if not (0 <= index.row() < len(self._df) and 0 <= index.column() < len(self._df.columns)):
            return False

        if role_enum in (EditRole, DisplayRole) or role in ("edit", "display"):
            col_name = self._df.columns[index.column()]
            row_idx = index.row()

            # Update DataFrame using Polars API
            try:
                # Convert value to appropriate type based on column dtype
                dtype = self._df[col_name].dtype
                if dtype in (pl.Int64, pl.Int32, pl.Int16, pl.Int8):
                    typed_value = int(value)
                elif dtype in (pl.Float64, pl.Float32):
                    typed_value = float(value)
                else:
                    typed_value = str(value)

                # Update the specific cell
                self._df[row_idx, col_name] = typed_value

                self.dataChanged.emit(index, index, [DisplayRole, EditRole])
                return True
            except (ValueError, TypeError) as e:
                print(f"[POSTGRES MODEL ERROR]: Failed to set data: {e}")
                return False

        return False

    def headerData(self, section: int, orientation: Qt.Orientation, role: int = DisplayRole) -> str | int | None:
        """Return header labels."""
        role_enum = Qt.ItemDataRole(role)

        if role_enum != DisplayRole:
            return None

        if orientation == Qt.Orientation.Horizontal:
            if 0 <= section < len(self._df.columns):
                # Convert snake_case to Sentence case (e.g., "task_date" -> "Task date")
                col_name = self._df.columns[section]
                return col_name.replace("_", " ").capitalize()
        elif orientation == Qt.Orientation.Vertical:
            return section + 1

        return None

    def flags(self, index: QModelIndex | QPersistentModelIndex) -> Qt.ItemFlag:
        """Return item flags - all cells editable."""
        if not index.isValid():
            return Qt.ItemFlag.NoItemFlags

        return (
            Qt.ItemFlag.ItemIsSelectable
            | Qt.ItemFlag.ItemIsEnabled
            | Qt.ItemFlag.ItemIsEditable
        )

    # ========================================================================
    # OPTIONAL METHODS
    # ========================================================================

    @Slot(int, Qt.SortOrder)
    def sort(self, column: int, order: Qt.SortOrder = Qt.SortOrder.AscendingOrder) -> None:
        """Sort DataFrame by column."""
        if not (0 <= column < len(self._df.columns)):
            return

        self.layoutAboutToBeChanged.emit()

        self._sort_column = column
        self._sort_order = order

        col_name = self._df.columns[column]
        descending = order == Qt.SortOrder.DescendingOrder
        self._df = self._df.sort(col_name, descending=descending)

        self.layoutChanged.emit()

    @property
    def sortColumn(self) -> int:
        """Current sort column."""
        return self._sort_column

    @property
    def sortOrder(self) -> Qt.SortOrder:
        """Current sort order."""
        return self._sort_order

    def insertRows(
        self,
        row: int,
        count: int,
        parent: QModelIndex | QPersistentModelIndex = QModelIndex(),
    ) -> bool:
        """Insert empty rows into DataFrame."""
        if row < 0 or row > len(self._df) or count < 1:
            return False

        self.beginInsertRows(parent, row, row + count - 1)

        # Create empty rows with None values
        empty_rows = pl.DataFrame(
            [[None] * len(self._df.columns) for _ in range(count)],
            schema=self._df.schema,
            orient="row",
        )

        # Insert into DataFrame
        if row == 0:
            self._df = pl.concat([empty_rows, self._df])
        elif row >= len(self._df):
            self._df = pl.concat([self._df, empty_rows])
        else:
            self._df = pl.concat([self._df[:row], empty_rows, self._df[row:]])

        self.endInsertRows()
        return True

    @Slot(int, result=bool)
    def addRow(self, row: int = -1) -> bool:
        """Add single row."""
        if row < 0:
            row = len(self._df)
        return self.insertRows(row, 1)

    @Slot(int, int, result=bool)
    def addRows(self, row: int, count: int) -> bool:
        """Add multiple rows."""
        if row < 0:
            row = len(self._df)
        return self.insertRows(row, count)

    def removeRows(
        self,
        row: int,
        count: int,
        parent: QModelIndex | QPersistentModelIndex = QModelIndex(),
    ) -> bool:
        """Remove rows from DataFrame."""
        if row < 0 or row >= len(self._df) or count < 1:
            return False

        if row + count > len(self._df):
            return False

        self.beginRemoveRows(parent, row, row + count - 1)

        # Remove rows using Polars slicing
        indices = list(range(len(self._df)))
        for _ in range(count):
            indices.pop(row)

        self._df = self._df[indices]

        self.endRemoveRows()
        return True

    @Slot(QModelIndex)
    def doSomethingWithCell(self, index: QModelIndex) -> None:
        """Custom action - show column statistics."""
        if not index.isValid():
            return

        row = index.row()
        col = index.column()
        col_name = self._df.columns[col]
        value = self.data(index, DisplayRole)

        # Get column statistics
        col_data = self._df[col_name]
        stats = col_data.describe()

        print("=" * 60)
        print("PostgreSQL Model - doSomethingWithCell() called!")
        print(f"  Row: {row}")
        print(f"  Column: {col} ({col_name})")
        print(f"  Value: {value}")
        print(f"\nColumn '{col_name}' statistics:")
        print(stats)
        print("=" * 60)
