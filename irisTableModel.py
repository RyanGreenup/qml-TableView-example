import duckdb
from pathlib import Path
from typing import cast
from PySide6.QtCore import (
    QAbstractTableModel,
    QPersistentModelIndex,
    Qt,
    QModelIndex,
    Slot,
)

DisplayRole = Qt.ItemDataRole.DisplayRole
EditRole = Qt.ItemDataRole.EditRole


class IrisTableModel(QAbstractTableModel):
    """
    DuckDB-backed table model using the Iris dataset.

    This model demonstrates:
    - Loading data from scikit-learn
    - Persisting to a DuckDB file
    - Implementing all table operations against DuckDB
    - Efficient SQL-based sorting and data manipulation
    """

    def __init__(self, db_path: str = "iris_data.duckdb", parent=None):
        super().__init__(parent)

        self.db_path = Path(db_path)
        self.conn: duckdb.DuckDBPyConnection

        # Column definitions for iris dataset
        self._columns = [
            "sepal_length",
            "sepal_width",
            "petal_length",
            "petal_width",
            "species",
        ]

        # Sorting state
        self._sort_column = -1
        self._sort_order = Qt.SortOrder.AscendingOrder

        # Initialize database
        self._init_database()

    def _init_database(self):
        """Initialize DuckDB database with iris dataset."""
        # Create connection
        self.conn = duckdb.connect(str(self.db_path))

        # Check if table already exists
        result = self.conn.execute(
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'iris'"
        ).fetchone()
        assert result is not None

        if result[0] == 0:
            # Load iris dataset from scikit-learn
            from sklearn.datasets import load_iris
            from sklearn.utils import Bunch

            iris = cast(Bunch, load_iris())

            # Create table and insert data
            self.conn.execute("""
                CREATE TABLE iris (
                    id INTEGER PRIMARY KEY,
                    sepal_length DOUBLE,
                    sepal_width DOUBLE,
                    petal_length DOUBLE,
                    petal_width DOUBLE,
                    species VARCHAR
                )
            """)

            # Species mapping
            species_names = iris.target_names

            # Insert data
            for idx, (features, target) in enumerate(zip(iris.data, iris.target)):
                self.conn.execute(
                    """
                    INSERT INTO iris VALUES (?, ?, ?, ?, ?, ?)
                """,
                    [
                        idx,
                        float(features[0]),
                        float(features[1]),
                        float(features[2]),
                        float(features[3]),
                        species_names[target],
                    ],
                )

            print(f"[IRIS MODEL]: Created new database with {len(iris.data)} rows")
        else:
            print(f"[IRIS MODEL]: Loaded existing database from {self.db_path}")

        # Cache row count
        self._cached_row_count = self._get_row_count()

    def _get_row_count(self) -> int:
        """Get total row count from database."""
        result = self.conn.execute("SELECT COUNT(*) FROM iris").fetchone()
        assert result is not None
        return result[0]

    def _get_row_by_position(self, row: int) -> list | None:
        """
        Get row data by position (after sorting).

        Uses the current sort order to fetch the correct row.
        """
        query = "SELECT id, sepal_length, sepal_width, petal_length, petal_width, species FROM iris"

        # Apply sorting if active
        if self._sort_column >= 0:
            col_name = self._columns[self._sort_column]
            order = "DESC" if self._sort_order == Qt.SortOrder.DescendingOrder else "ASC"
            query += f" ORDER BY {col_name} {order}"

        # Fetch the specific row
        query += f" LIMIT 1 OFFSET {row}"

        result = self.conn.execute(query).fetchone()
        return list(result) if result else None

    # ========================================================================
    # REQUIRED METHODS - QAbstractTableModel interface
    # ========================================================================

    def rowCount(self, parent: QModelIndex | QPersistentModelIndex = QModelIndex()):
        """Return number of rows in the table."""
        if parent.isValid():
            return 0  # Table models have no children
        return self._cached_row_count

    def columnCount(self, parent: QModelIndex | QPersistentModelIndex = QModelIndex()):
        """Return number of columns in the table."""
        if parent.isValid():
            return 0  # Table models have no children
        return len(self._columns)

    def data(self, index, role: int = DisplayRole):
        """
        Return data for the given cell and role.

        Fetches data from DuckDB based on current sort order.
        """
        role = Qt.ItemDataRole(role)

        if not index.isValid():
            return None

        if index.row() < 0 or index.row() >= self._cached_row_count:
            return None

        if index.column() < 0 or index.column() >= len(self._columns):
            return None

        if role in (DisplayRole, EditRole):
            row_data = self._get_row_by_position(index.row())
            if row_data:
                # row_data[0] is id, columns start at index 1
                value = row_data[index.column() + 1]
                # Format floats to 2 decimal places
                if isinstance(value, float):
                    return f"{value:.2f}"
                return str(value)

        return None

    def setData(self, index, value, role: int = EditRole):
        """
        Handle cell editing - updates DuckDB database.
        """
        role = Qt.ItemDataRole(role)

        if not index.isValid():
            return False

        if index.row() < 0 or index.row() >= self._cached_row_count:
            return False

        if index.column() < 0 or index.column() >= len(self._columns):
            return False

        if role in (EditRole, DisplayRole) or role == "edit" or role == "display":
            # Get the row's ID
            row_data = self._get_row_by_position(index.row())
            if not row_data:
                return False

            row_id = row_data[0]
            col_name = self._columns[index.column()]

            # Convert value to appropriate type
            try:
                if index.column() < 4:  # Numeric columns
                    value = float(value)
                else:  # Species column
                    value = str(value)
            except (ValueError, TypeError):
                return False

            # Update database
            try:
                self.conn.execute(
                    f"UPDATE iris SET {col_name} = ? WHERE id = ?", [value, row_id]
                )

                # Notify views that data changed
                self.dataChanged.emit(index, index, [DisplayRole, EditRole])
                return True
            except Exception as e:
                print(f"[IRIS MODEL ERROR]: Failed to update data: {e}")
                return False

        return False

    def headerData(self, section, orientation, role: int = DisplayRole):
        """Return header labels for columns and rows."""
        role = Qt.ItemDataRole(role)

        if role != DisplayRole:
            return None

        if orientation == Qt.Orientation.Horizontal:
            if 0 <= section < len(self._columns):
                # Format column names nicely
                return self._columns[section].replace("_", " ").title()
        elif orientation == Qt.Orientation.Vertical:
            return section + 1

        return None

    def flags(self, index):
        """Return item flags - makes cells editable."""
        if not index.isValid():
            return Qt.ItemFlag.NoItemFlags

        return (
            Qt.ItemFlag.ItemIsSelectable
            | Qt.ItemFlag.ItemIsEnabled
            | Qt.ItemFlag.ItemIsEditable
        )

    # ========================================================================
    # OPTIONAL METHODS - Enhanced functionality
    # ========================================================================

    @Slot(int, Qt.SortOrder)
    def sort(self, column, order=Qt.SortOrder.AscendingOrder):
        """
        Sort the table by the given column.

        Uses DuckDB's sorting - very efficient even for large datasets.
        """
        if column < 0 or column >= len(self._columns):
            return

        # Notify views that layout is about to change
        self.layoutAboutToBeChanged.emit()

        # Store sort state
        self._sort_column = column
        self._sort_order = order

        # No need to actually sort data - it's done on-the-fly in _get_row_by_position

        # Notify views that layout changed
        self.layoutChanged.emit()

    @property
    def sortColumn(self):
        """Current sort column (-1 if not sorted)."""
        return self._sort_column

    @property
    def sortOrder(self):
        """Current sort order."""
        return self._sort_order

    def insertRows(
        self,
        row: int,
        count: int,
        parent: QModelIndex | QPersistentModelIndex = QModelIndex(),
    ) -> bool:
        """
        Insert multiple empty rows into the database.

        New rows are created with default values and inserted into DuckDB.
        """
        print(f"[IRIS MODEL]: insertRows() called with row={row}, count={count}")

        if row < 0 or row > self._cached_row_count:
            return False

        if count < 1:
            return False

        # Notify views about the insertion
        self.beginInsertRows(parent, row, row + count - 1)

        try:
            # Get the maximum ID to generate new IDs
            max_id_result = self.conn.execute("SELECT MAX(id) FROM iris").fetchone()
            assert max_id_result is not None
            next_id = (max_id_result[0] + 1) if max_id_result[0] is not None else 0

            # Insert rows with default data
            for i in range(count):
                self.conn.execute(
                    """
                    INSERT INTO iris (id, sepal_length, sepal_width, petal_length, petal_width, species)
                    VALUES (?, ?, ?, ?, ?, ?)
                """,
                    [next_id + i, 5.0, 3.0, 4.0, 1.0, "setosa"],
                )

            # Update cached row count
            self._cached_row_count = self._get_row_count()

            # Notify views that insertion is complete
            self.endInsertRows()

            print(
                f"[IRIS MODEL]: Rows inserted successfully. New count: {self._cached_row_count}"
            )
            return True
        except Exception as e:
            print(f"[IRIS MODEL ERROR]: Failed to insert rows: {e}")
            self.endInsertRows()
            return False

    @Slot(int, result=bool)
    def addRow(self, row=-1):
        """Custom convenience method - inserts a new row with default values."""
        if row < 0:
            row = self._cached_row_count
        return self.insertRows(row, 1)

    @Slot(int, int, result=bool)
    def addRows(self, row, count):
        """Custom convenience method - inserts multiple rows."""
        if row < 0:
            row = self._cached_row_count
        return self.insertRows(row, count)

    def removeRows(
        self, row, count, parent: QModelIndex | QPersistentModelIndex = QModelIndex()
    ):
        """
        Remove multiple rows from the database.

        Deletes rows from DuckDB based on their IDs.
        """
        if row < 0 or row >= self._cached_row_count:
            return False

        if count < 1:
            return False

        if row + count > self._cached_row_count:
            return False

        # Notify views about the removal
        self.beginRemoveRows(parent, row, row + count - 1)

        try:
            # Get IDs of rows to delete
            ids_to_delete = []
            for i in range(count):
                row_data = self._get_row_by_position(row + i)
                if row_data:
                    ids_to_delete.append(row_data[0])

            # Delete from database
            for row_id in ids_to_delete:
                self.conn.execute("DELETE FROM iris WHERE id = ?", [row_id])

            # Update cached row count
            self._cached_row_count = self._get_row_count()

            # Notify views that removal is complete
            self.endRemoveRows()
            return True
        except Exception as e:
            print(f"[IRIS MODEL ERROR]: Failed to remove rows: {e}")
            self.endRemoveRows()
            return False

    @Slot(QModelIndex)
    def doSomethingWithCell(self, index):
        """
        Custom business logic - called when user presses F1 on a cell.

        Demonstrates querying DuckDB for statistics about the selected species.
        """
        if not index.isValid():
            return

        row = index.row()
        col = index.column()
        value = self.data(index, DisplayRole)
        column_name = self._columns[col]

        row_data = self._get_row_by_position(row)
        if not row_data:
            return

        species = row_data[5]  # Species is at index 5

        # Query statistics for this species
        stats = self.conn.execute(
            """
            SELECT
                COUNT(*) as count,
                AVG(sepal_length) as avg_sepal_length,
                AVG(sepal_width) as avg_sepal_width,
                AVG(petal_length) as avg_petal_length,
                AVG(petal_width) as avg_petal_width
            FROM iris
            WHERE species = ?
        """,
            [species],
        ).fetchone()
        assert stats is not None

        print("=" * 60)
        print("Iris Model - doSomethingWithCell() called!")
        print(f"  Row: {row}")
        print(f"  Column: {col} ({column_name})")
        print(f"  Value: {value}")
        print(f"  Species: {species}")
        print(f"\nStatistics for {species}:")
        print(f"  Total count: {stats[0]}")
        print(f"  Avg sepal length: {stats[1]:.2f}")
        print(f"  Avg sepal width: {stats[2]:.2f}")
        print(f"  Avg petal length: {stats[3]:.2f}")
        print(f"  Avg petal width: {stats[4]:.2f}")
        print("=" * 60)

    def __del__(self):
        """Clean up database connection."""
        if self.conn:
            self.conn.close()
