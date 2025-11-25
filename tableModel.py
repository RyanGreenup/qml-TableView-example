from PySide6.QtCore import (
    QAbstractTableModel,
    QPersistentModelIndex,
    Qt,
    QModelIndex,
    Slot,
)

DisplayRole = Qt.ItemDataRole.DisplayRole
EditRole = Qt.ItemDataRole.EditRole


class PythonTableModel(QAbstractTableModel):
    """
    Example table model backed by Python data structures.

    This demonstrates the minimal implementation needed to work with
    the anotherTable.qml component. In production, you might back this
    with a pandas DataFrame, database query results, or other data source.
    """

    def __init__(self, parent=None):
        super().__init__(parent)

        # Column definitions
        self._columns = ["Name", "Age", "City", "Score", "Status"]

        # Sample data (list of lists)
        # In production, this might be a pandas DataFrame, SQL results, etc.
        self._data = [
            ["Alice", 28, "New York", 95.5, "Active"],
            ["Bob", 34, "San Francisco", 87.2, "Active"],
            ["Charlie", 25, "Seattle", 92.8, "Inactive"],
            ["Diana", 31, "Austin", 88.9, "Active"],
            ["Eve", 29, "Boston", 91.3, "Active"],
            ["Frank", 42, "Chicago", 85.6, "Inactive"],
            ["Grace", 27, "Denver", 94.2, "Active"],
            ["Henry", 36, "Portland", 89.7, "Active"],
            ["Ivy", 30, "Miami", 93.1, "Active"],
            ["Jack", 33, "Phoenix", 86.4, "Inactive"],
        ]

        # Sorting state (tracks current sort column and order)
        self._sort_column = -1
        self._sort_order = Qt.SortOrder.AscendingOrder

    # ========================================================================
    # REQUIRED METHODS - QAbstractTableModel interface
    # ========================================================================

    def rowCount(self, parent: QModelIndex | QPersistentModelIndex = QModelIndex()):
        """Return number of rows in the table."""
        if parent.isValid():
            return 0  # Table models have no children
        return len(self._data)

    def columnCount(self, parent: QModelIndex | QPersistentModelIndex = QModelIndex()):
        """Return number of columns in the table."""
        if parent.isValid():
            return 0  # Table models have no children
        return len(self._columns)

    def data(self, index, role: int = DisplayRole):
        """
        Return data for the given cell and role.

        QML will call this with DisplayRole for showing data,
        and EditRole when entering edit mode.
        """
        # Handle type checking
        role = Qt.ItemDataRole(role)

        if not index.isValid():
            return None

        if index.row() < 0 or index.row() >= len(self._data):
            return None

        if index.column() < 0 or index.column() >= len(self._columns):
            return None

        # Handle both DisplayRole and EditRole (both return the same data)
        if role in (DisplayRole, EditRole):
            return str(self._data[index.row()][index.column()])

        return None

    def setData(self, index, value, role: int = EditRole):
        """
        Handle cell editing - called when user commits changes in editDelegate.

        This is called from QML via:
            tableView.model.setData(tableView.model.index(row, column), text, "edit")
        """
        # Handle type checking
        role = Qt.ItemDataRole(role)
        if not index.isValid():
            return False

        if index.row() < 0 or index.row() >= len(self._data):
            return False

        if index.column() < 0 or index.column() >= len(self._columns):
            return False

        # Handle both "edit" (from QML) and Qt.EditRole (from C++)
        if role in (EditRole, DisplayRole) or role == "edit" or role == "display":
            # Convert value to appropriate type based on column
            try:
                if index.column() == 1:  # Age column
                    value = int(value)
                elif index.column() == 3:  # Score column
                    value = float(value)
                else:
                    value = str(value)
            except (ValueError, TypeError):
                return False  # Invalid conversion

            # Update the data
            self._data[index.row()][index.column()] = value

            # Notify views that data changed
            self.dataChanged.emit(index, index, [DisplayRole, EditRole])
            return True

        return False

    @Slot(int, Qt.Orientation, int, result=str)
    def headerData(self, section, orientation, role: int = DisplayRole):
        """
        Return header labels for columns and rows.

        Called from QML via:
            tableView.model.headerData(index, Qt.Horizontal/Qt.Vertical, Qt.DisplayRole)
        """
        # Handle type checking
        role = Qt.ItemDataRole(role)

        if role != DisplayRole:
            return ""  # Return empty string instead of None for QML compatibility

        if orientation == Qt.Orientation.Horizontal:
            # Column headers
            if 0 <= section < len(self._columns):
                return self._columns[section]
            # Return empty string for out-of-bounds columns
            return ""
        elif orientation == Qt.Orientation.Vertical:
            # Row numbers (1-based)
            if 0 <= section < len(self._data):
                return str(section + 1)
            return ""

        return ""  # Default: return empty string instead of None

    def flags(self, index):
        """
        Return item flags - makes cells editable.

        Qt uses this to determine if a cell can be edited.
        """
        if not index.isValid():
            return Qt.ItemFlag.NoItemFlags

        # All cells are selectable and editable
        Qt.ItemSelectionOperation
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

        Called from QML when user clicks column headers:
            tableView.model.sort(columnIndex, Qt.AscendingOrder/Qt.DescendingOrder)
        """
        if column < 0 or column >= len(self._columns):
            return

        # Notify views that layout is about to change
        self.layoutAboutToBeChanged.emit()

        # Store sort state
        self._sort_column = column
        self._sort_order = order

        # Sort the data
        reverse = order == Qt.SortOrder.DescendingOrder

        try:
            # Try numeric sort first (for Age and Score columns)
            if column in (1, 3):  # Age or Score
                self._data.sort(key=lambda row: float(row[column]), reverse=reverse)
            else:
                # String sort
                self._data.sort(key=lambda row: str(row[column]), reverse=reverse)
        except (ValueError, TypeError):
            # Fallback to string sort if numeric fails
            self._data.sort(key=lambda row: str(row[column]), reverse=reverse)

        # Notify views that layout changed
        self.layoutChanged.emit()

    # Expose sort state as properties so QML can show sort indicators
    @property
    def sortColumn(self):
        """Current sort column (-1 if not sorted)."""
        return self._sort_column

    @property
    def sortOrder(self):
        """Current sort order (Qt.AscendingOrder or Qt.DescendingOrder)."""
        return self._sort_order

    def insertRows(
        self,
        row: int,
        count: int,
        parent: QModelIndex | QPersistentModelIndex = QModelIndex(),
    ) -> bool:
        """
        Insert multiple empty rows into the model (Qt standard method).

        This is the virtual method that Qt expects you to override.
        The convenience method insertRow(row, parent) calls this automatically.

        NOTE: Qt's design separates row creation from data population:
        1. insertRows() creates empty slots
        2. setData() populates the data

        However, for practical use, we create rows with default values.

        Args:
            row: Starting row index
            count: Number of rows to insert
            parent: Parent index (unused for table models)

        Returns:
            bool: True if successful, False otherwise
        """
        print(f"[PYTHON]: insertRows() called with row={row}, count={count}")
        print(f"[PYTHON]: Current data length: {len(self._data)}")

        # Validate parameters
        if row < 0 or row > len(self._data):
            print(
                f"[PYTHON]: Invalid row index! row={row}, data length={len(self._data)}"
            )
            return False

        if count < 1:
            print(f"[PYTHON]: Invalid count! count={count}")
            return False

        print(f"[PYTHON]: Inserting {count} row(s) at position {row}")

        # Notify views about the insertion
        self.beginInsertRows(parent, row, row + count - 1)

        # Insert rows with default data
        for i in range(count):
            default_row = [
                f"New Person {len(self._data) + 1}",  # Name
                25,  # Age
                "Unknown",  # City
                0.0,  # Score
                "Active",  # Status
            ]
            self._data.insert(row + i, default_row)
            print(f"[PYTHON]:   Inserted row {row + i}: {default_row}")

        # Notify views that insertion is complete
        self.endInsertRows()

        print(
            f"[PYTHON]: Rows inserted successfully. New data length: {len(self._data)}"
        )
        return True

    @Slot(int, result=bool)
    def addRow(self, row: int = -1):
        """
        Custom convenience method - inserts a new row with default values.

        It's required because the QML insertRow API differs with the
        QAbstractTableModel insertRow API as a compromise we have both call
        this method

        1. It handles -1 as "append to end"
        2. It provides default values automatically

        Called from QML via:
            tableView.model.addRow(insertPosition)

        Note: This calls insertRows() internally to follow Qt conventions.
        """
        print(f"[PYTHON]: addRow() called with row={row}")

        if row < 0:
            row = len(self._data)  # Append at end

        return self.insertRows(row, 1)

    @Slot(int, int, result=bool)
    def addRows(self, row, count):
        """
        Custom convenience method - inserts multiple rows with default values.

        Called from QML via:
            tableView.model.addRows(insertPosition, count)

        Note: This calls insertRows() internally to follow Qt conventions.
        """
        print(f"[PYTHON]: addRows() called with row={row}, count={count}")

        if row < 0:
            row = len(self._data)

        return self.insertRows(row, count)

    def removeRows(
        self, row, count, parent: QModelIndex | QPersistentModelIndex = QModelIndex()
    ):
        """
        Remove multiple rows from the table.

        This is the Qt standard method that should be overridden.
        The convenience method removeRow(row, parent) calls this automatically.

        Called from QML via:
            tableView.model.removeRow(rowIndex)  // Calls removeRows(rowIndex, 1, QModelIndex())

        Args:
            row: Starting row index
            count: Number of rows to remove
            parent: Parent index (unused for table models)

        Returns:
            bool: True if successful, False otherwise
        """
        # Validate parameters
        if row < 0 or row >= len(self._data):
            print(
                f"[PYTHON ERROR]: Invalid row index! row={row}, data length={len(self._data)}"
            )
            return False

        if count < 1:
            print(f"[PYTHON ERROR]: Invalid count! count={count}")
            return False

        if row + count > len(self._data):
            print(
                f"[PYTHON ERROR]: Row range exceeds data! row={row}, count={count}, data length={len(self._data)}"
            )
            return False

        # Notify views about the removal
        self.beginRemoveRows(parent, row, row + count - 1)

        # Remove the rows (remove from same index 'count' times)
        for i in range(count):
            del self._data[row]

        # Notify views that removal is complete
        self.endRemoveRows()
        return True

    @Slot(QModelIndex)
    def doSomethingWithCell(self, index):
        """
        Custom business logic - called when user presses F1 on a cell.

        This demonstrates how to add custom Q_INVOKABLE methods that
        can be called from QML. In production, this might:
        - Validate data
        - Call backend APIs
        - Update a database
        - Open dialogs
        - Emit custom signals

        Called from QML via:
            tableView.model.doSomethingWithCell(index)
        """
        if not index.isValid():
            return

        row = index.row()
        col = index.column()
        value = self.data(index, DisplayRole)
        column_name = self._columns[col]

        print("=" * 60)
        print("Python Model - doSomethingWithCell() called!")
        print(f"  Row: {row}")
        print(f"  Column: {col} ({column_name})")
        print(f"  Value: {value}")
        print(f"  Data type: {type(self._data[row][col]).__name__}")
        print("=" * 60)

        # Example: Business logic based on column
        if col == 4:  # Status column
            print(f"→ Status check: User '{self._data[row][0]}' is {value}")
        elif col == 3:  # Score column
            score = self._data[row][col]
            if score >= 90:
                print(f"→ High performer! Score: {score}")
            else:
                print(f"→ Score could be improved: {score}")
