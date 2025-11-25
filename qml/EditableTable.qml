pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Qt.labs.qmlmodels

ApplicationWindow {
    width: 800
    height: 600
    visible: true
    // title: "Table View"

    menuBar: MenuBar {
        Menu {
            title: "&Options"
            Action {
                text: "Enable Left-Click &Drag"
                shortcut: "Ctrl+D"
                checkable: true
                checked: tableContainer.dragButtons === Qt.LeftButton
                onTriggered: tableContainer.dragButtons = tableContainer.dragButtons === Qt.NoButton ? Qt.LeftButton : Qt.NoButton
            }
            Action {
                text: "Enable &Resizing"
                shortcut: "Ctrl+R"
                checkable: true
                checked: tableContainer.resizingEnabled
                onTriggered: tableContainer.resizingEnabled = !tableContainer.resizingEnabled
            }
            Action {
                text: "&Hide Headers"
                shortcut: "Ctrl+H"
                checkable: true
                checked: tableContainer.hideHeaders
                onTriggered: tableContainer.hideHeaders = !tableContainer.hideHeaders
            }
            Action {
                text: "&Auto-Size Columns"
                shortcut: "Ctrl+A"
                checkable: true
                checked: tableContainer.autoSizeColumns
                onTriggered: {
                    tableContainer.autoSizeColumns = !tableContainer.autoSizeColumns;
                    tableView.forceLayout();
                }
            }
            Action {
                text: "Reset Column &Widths"
                shortcut: "Ctrl+Shift+R"
                onTriggered: {
                    tableView.clearColumnWidths();
                    tableView.forceLayout();
                }
            }
        }
        Menu {
            title: "&Data"
            Action {
                text: "&Insert New Row"
                shortcut: "Ctrl+N"
                onTriggered: {
                    // Insert before current row, or at end if no selection
                    let insertPosition = tableView.selectionModel.currentIndex.row;

                    // Use addRow() - custom method with C++/Python-compatible API
                    // This works identically when model is QML TableModel or C++/Python QAbstractTableModel
                    // See model's addRow() implementation for C++/Python migration examples
                    tableView.model.addRow(insertPosition);
                }
            }
            Action {
                text: "Insert &Multiple Rows"
                shortcut: "Ctrl+Shift+N"
                onTriggered: {
                    // Insert before current row, or at end if no selection
                    let insertPosition = tableView.selectionModel.currentIndex.row;

                    // Use addRows() - custom convenience method
                    // Inserts 3 rows with default data at the specified position
                    // See model's addRows() implementation for C++/Python migration examples
                    tableView.model.addRows(insertPosition, 3);
                }
            }
            Action {
                text: "&Remove Current Row"
                shortcut: "Ctrl+Shift+D"
                enabled: tableView.selectionModel.currentIndex.row >= 0
                onTriggered: {
                    let rowToRemove = tableView.selectionModel.currentIndex.row;

                    // Use removeRow() - standard Qt method that works for both:
                    // - QML TableModel: removeRow(row, count=1) - returns undefined
                    // - C++/Python QAbstractTableModel: removeRow(row, parent) -> returns bool
                    let result = tableView.model.removeRow(rowToRemove);

                    // Check for explicit failure (false), not undefined
                    // QML TableModel returns undefined, Python returns bool
                    if (result === false) {
                        console.error("[QML ERROR]: Failed to remove row", rowToRemove);
                    }
                }
            }
        }
    }

    Item {
        id: tableContainer
        objectName: "tableContainer"
        anchors.fill: parent

        // ========================================================================
        // DATA MODEL CONFIGURATION
        // ========================================================================
        // The table model can be set from C++/Python or use the default example model.
        //
        // USAGE FROM C++/PYTHON:
        //   QML side:
        //     tableContainer.tableModel = myCustomModel
        //
        //   Python (PySide6) example:
        //     from PySide6.QtCore import QAbstractTableModel, Qt
        //     engine.rootContext().setContextProperty("myCustomModel", MyTableModel())
        //
        //   C++ example:
        //     engine.rootContext()->setContextProperty("myCustomModel", new MyTableModel());
        //
        // The model should implement QAbstractTableModel or QAbstractItemModel:
        //   - data(QModelIndex, role) - return cell data
        //   - setData(QModelIndex, value, role) - handle cell editing
        //   - headerData(section, orientation, role) - return header labels
        //   - rowCount(), columnCount() - return dimensions
        //
        // Optional methods for enhanced functionality:
        //   - sort(column, order) - enable column sorting
        //   - insertRow/removeRow - enable row insertion/deletion
        //   - Custom Q_INVOKABLE methods - callable from QML (e.g., doSomethingWithCell)
        // ========================================================================
        property var tableModel: null  // Set to your C++/Python model, or null to use ExampleTableModel

        // ========================================================================
        // BEHAVIOR CONFIGURATION
        // ========================================================================
        property bool hideHeaders: false
        property bool resizingEnabled: true
        property int dragButtons: Qt.NoButton
        property bool autoSizeColumns: true

        // ========================================================================
        // STYLING CONFIGURATION
        // ========================================================================

        // Color Palette (Design Tokens)
        // Headers
        property color headerBackgroundColor: palette.button
        property color headerTextColor: palette.buttonText
        property color headerBorderColor: palette.mid

        // Cells
        property color cellBackgroundColor: palette.base
        property color cellSelectedColor: palette.highlight
        property color cellTextColor: palette.text
        property color cellCurrentBorderColor: palette.highlight

        // Table
        property color tableFocusBorderColor: palette.highlight
        property color tableBackgroundColor: "transparent"

        // Horizontal Header Styling
        property int horizontalHeaderHeight: 30
        property int horizontalHeaderBorderWidth: 1

        // Vertical Header Styling
        property int verticalHeaderWidth: 40
        property int verticalHeaderBorderWidth: 1

        // Cell Styling
        property int cellHeight: 25
        property int cellBorderWidth: 2  // Border width for current cell
        property int cellPaddingHorizontal: 10

        // Table Styling
        property int tableRowSpacing: 1
        property int tableColumnSpacing: 1
        property int tableFocusBorderWidth: 2

        // Column Width Constraints (for auto-sizing)
        property int columnMinWidth: 60
        property int columnMaxWidth: 250
        property int columnDefaultWidth: 100

        // Header Sort Indicator
        property int sortIndicatorFontSize: 10
        property int headerTextSpacing: 4  // Spacing between header text and sort indicator

        HorizontalHeaderView {
            id: hHeader
            anchors.top: parent.top
            anchors.left: vHeader.right
            anchors.right: parent.right
            syncView: tableView
            clip: true
            // Enables user column resizing (Qt 6.5+):
            // - Drag column border to manually resize
            // - Double-click column border to auto-fit to content
            // Resized widths are stored via setColumnWidth() and retrieved via explicitColumnWidth()
            // https://doc.qt.io/qt-6/qml-qtquick-tableview.html#resizableColumns-prop
            resizableColumns: tableContainer.resizingEnabled
            // qmllint disable missing-property
            acceptedButtons: tableContainer.dragButtons
            visible: !tableContainer.hideHeaders

            delegate: Rectangle {
                id: horizontalHeaderDelegate
                implicitWidth: tableContainer.columnDefaultWidth
                implicitHeight: tableContainer.horizontalHeaderHeight
                required property int index
                color: tableContainer.headerBackgroundColor
                border.width: tableContainer.horizontalHeaderBorderWidth
                border.color: tableContainer.headerBorderColor

                Row {
                    anchors.centerIn: parent
                    spacing: tableContainer.headerTextSpacing

                    Text {
                        id: headerText
                        text: tableView.model.headerData(horizontalHeaderDelegate.index, Qt.Horizontal, Qt.DisplayRole) || ""
                        font.bold: true
                        color: tableContainer.headerTextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Sort indicator (▲ ascending, ▼ descending)
                    Text {
                        text: {
                            // Check if model has sorting properties
                            if (tableView.model.sortColumn === undefined)
                                return "";

                            if (tableView.model.sortColumn === horizontalHeaderDelegate.index) {
                                return tableView.model.sortOrder === Qt.AscendingOrder ? "▲" : "▼";
                            }
                            return "";
                        }
                        font.pixelSize: tableContainer.sortIndicatorFontSize
                        color: tableContainer.headerTextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function (mouse) {
                        // Check if model supports sorting (duck typing - Qt convention)
                        if (typeof tableView.model.sort !== 'function') {
                            console.warn("Model does not implement sort() function");
                            return;
                        }

                        // Right-click: clear sort (restore original order)
                        if (mouse.button === Qt.RightButton) {
                            if (typeof tableView.model.clearSort === 'function') {
                                tableView.model.clearSort();
                            }
                            return;
                        }

                        // Left-click: Qt convention - toggle sort order on same column, ascending on new column
                        let newOrder = Qt.AscendingOrder;
                        if (tableView.model.sortColumn === horizontalHeaderDelegate.index) {
                            // Same column: toggle between ascending/descending
                            newOrder = tableView.model.sortOrder === Qt.AscendingOrder ? Qt.DescendingOrder : Qt.AscendingOrder;
                        }
                        tableView.model.sort(horizontalHeaderDelegate.index, newOrder);
                    }
                }
            }
        }

        VerticalHeaderView {
            id: vHeader

            // TODO clicking the Vertical HeaderView Steals focus from the Table
            focus: false
            focusPolicy: Qt.NoFocus

            anchors.top: hHeader.bottom
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            syncView: tableView
            clip: true
            resizableRows: tableContainer.resizingEnabled
            // qmllint disable missing-property
            acceptedButtons: tableContainer.dragButtons
            visible: !tableContainer.hideHeaders

            delegate: Rectangle {
                id: verticalHeaderDelegate
                implicitWidth: tableContainer.verticalHeaderWidth
                implicitHeight: tableContainer.cellHeight
                required property int index
                color: tableContainer.headerBackgroundColor
                border.width: tableContainer.verticalHeaderBorderWidth
                border.color: tableContainer.headerBorderColor
                focus: false
                focusPolicy: Qt.NoFocus

                Text {
                    focus: false
                    focusPolicy: Qt.NoFocus
                    anchors.centerIn: parent
                    text: tableView.model.headerData(verticalHeaderDelegate.index, Qt.Vertical, Qt.DisplayRole) || ""
                    font.bold: true
                    color: tableContainer.headerTextColor
                }
            }
        }

        Rectangle {
            anchors.top: tableContainer.hideHeaders ? parent.top : hHeader.bottom
            anchors.left: tableContainer.hideHeaders ? parent.left : vHeader.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            border.width: tableView.focus ? tableContainer.tableFocusBorderWidth : 0
            border.color: tableContainer.tableFocusBorderColor
            color: tableContainer.tableBackgroundColor

            TableView {
                id: tableView
                anchors.fill: parent
                clip: true
                interactive: true
                // qmllint disable missing-property
                acceptedButtons: tableContainer.dragButtons
                rowSpacing: tableContainer.tableRowSpacing
                columnSpacing: tableContainer.tableColumnSpacing
                focus: true
                editTriggers: TableView.DoubleTapped | TableView.EditKeyPressed

                // Use custom model if provided, otherwise fallback to example model
                model: tableContainer.tableModel ?? exampleModel
                selectionModel: ItemSelectionModel {
                    model: tableView.model
                }

                // Column width calculation with support for auto-sizing and user resizing
                // Priority order:
                // 1. explicitColumnWidth() - User manual resize (drag or double-click border)
                // 2. implicitColumnWidth() - Auto-sized to content (if enabled)
                // 3. Fixed fallback (100px)
                // https://doc.qt.io/qt-6/qml-qtquick-tableview.html#columnWidthProvider-prop
                columnWidthProvider: function (column) {
                    // First check if user manually resized this column (via drag or double-click)
                    // Double-click on column border auto-fits and stores result via setColumnWidth()
                    let explicitWidth = explicitColumnWidth(column);
                    if (explicitWidth >= 0)
                        return explicitWidth;  // Honor user's manual resize

                    // If auto-sizing is enabled, use content-aware sizing
                    if (tableContainer.autoSizeColumns) {
                        let contentWidth = implicitColumnWidth(column);
                        return Math.min(Math.max(tableContainer.columnMinWidth, contentWidth), tableContainer.columnMaxWidth);
                    }

                    // Fallback to fixed width when auto-sizing is disabled
                    return tableContainer.columnDefaultWidth;
                }

                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_F2) {
                        tableView.edit(tableView.model.index(selectionModel.currentIndex.row, selectionModel.currentIndex.column));
                        event.accepted = true;
                    }
                    if (event.key === Qt.Key_F1) {
                        // We can extract coumn and row and content
                        let col = selectionModel.currentIndex.column;
                        let row = selectionModel.currentIndex.row;
                        let index = tableView.model.index(row, col);

                        // It's Convention to only pass the index back to the Model
                        // let cellContent = tableView.model.data(index);
                        tableView.model.doSomethingWithCell(index);
                        event.accepted = true;
                    }
                }

                delegate: Rectangle {
                    id: root
                    implicitHeight: tableContainer.cellHeight
                    required property bool selected
                    required property bool current
                    required property bool editing
                    required property var display
                    required property int row
                    required property int column
                    color: selected ? tableContainer.cellSelectedColor : tableContainer.cellBackgroundColor
                    border.width: current ? tableContainer.cellBorderWidth : 0
                    border.color: tableContainer.cellCurrentBorderColor

                    Label {
                        id: cellLabel
                        text: root.display
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: tableContainer.cellPaddingHorizontal
                        rightPadding: tableContainer.cellPaddingHorizontal
                        visible: !root.editing
                    }

                    // Set implicitWidth based on Label's content width + padding
                    implicitWidth: cellLabel.implicitWidth + (tableContainer.cellPaddingHorizontal * 2)

                    TableView.editDelegate: TextField {
                        anchors.fill: parent
                        required property var display
                        required property int row
                        required property int column
                        text: display
                        Component.onCompleted: {
                            selectAll();
                            forceActiveFocus();
                        }
                        TableView.onCommit: {
                            // Handle C++ Models
                            tableView.model.setData(tableView.model.index(row, column), text, "edit");
                            // Required for QML Specific
                            tableView.model.setData(tableView.model.index(row, column), text, "display");
                        }
                        Keys.onEscapePressed: tableView.closeEditor()
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: tableView.selectionModel.setCurrentIndex(tableView.model.index(root.row, root.column), ItemSelectionModel.ClearsAndSelects)
                    }

                    objectName: "root"
                }
            }
        }
    }

    SelectionRectangle {
        target: tableView
    }

    // Default example model (used when tableContainer.tableModel is null)
    // This provides a self-contained demo and serves as documentation for
    // what a custom C++/Python model should implement
    ExampleTableModel {
        id: exampleModel
    }

    component ExampleTableModel: TableModel {
        // Single source of truth for column metadata
        readonly property var columnRoles: ["name", "color", "type", "age", "height", "weight", "speed", "origin", "pattern", "noise"]

        // Note: TableModel requires explicit TableModelColumn declarations
        // Keep these in sync with columnRoles array above
        TableModelColumn {
            display: "name"
            edit: "name"
        }
        TableModelColumn {
            display: "color"
            edit: "color"
        }
        TableModelColumn {
            display: "type"
            edit: "type"
        }
        TableModelColumn {
            display: "age"
            edit: "age"
        }
        TableModelColumn {
            display: "height"
            edit: "height"
        }
        TableModelColumn {
            display: "weight"
            edit: "weight"
        }
        TableModelColumn {
            display: "speed"
            edit: "speed"
        }
        TableModelColumn {
            display: "origin"
            edit: "origin"
        }
        TableModelColumn {
            display: "pattern"
            edit: "pattern"
        }
        TableModelColumn {
            display: "noise"
            edit: "noise"
        }

        rows: (function () {
                const rows = [];
                for (let i = 0; i < 1000; i++) {
                    rows.push({
                        name: `Item ${i + 1}`,
                        color: ["Red", "Green", "Blue", "Yellow", "Purple"][i % 5],
                        type: ["Type A", "Type B", "Type C"][i % 3],
                        age: 20 + (i % 50),
                        height: 150 + (i % 100),
                        weight: 50 + (i % 150),
                        speed: 10 + (i % 200),
                        origin: ["North", "South", "East", "West"][i % 4],
                        pattern: ["Solid", "Striped", "Dotted"][i % 3],
                        noise: (Math.random() * 100).toFixed(2)
                    });
                }
                return rows;
            })()

        // Helper: Convert role name to display header (e.g., "name" -> "Name")
        function roleToHeader(roleName) {
            return roleName.charAt(0).toUpperCase() + roleName.slice(1);
        }

        // Mimics QAbstractTableModel::headerData() from C++/Python
        // QVariant headerData(int section, Qt::Orientation orientation, int role = Qt::DisplayRole) const
        function headerData(section, orientation, role) {
            if (role === undefined)
                role = Qt.DisplayRole;

            // Handle both DisplayRole and EditRole (common Qt pattern)
            // Editing table Headers is rare because SQL doesn't like it
            // And the user can simply `SELECT colname AS "Column Name"
            if (role !== Qt.DisplayRole && role !== Qt.EditRole)
                return "";

            if (orientation === Qt.Horizontal) {
                return roleToHeader(columnRoles[section]) || "";
            }

            if (orientation === Qt.Vertical) {
                return section + 1;  // Row numbers (1-based)
            }

            return "";
        }

        function doSomethingWithCell(index) {
            if (!index.valid)
                return;

            // Extract once, inside the model
            let row = index.row;
            let col = index.column;
            let value = data(index, "display");

            console.log("Cell information:");
            console.log("  Row:", row);
            console.log("  Column:", col);
            console.log("  Index:", index);
            console.log("  Cell content:", value);
        }

        // Sorting state (mimics QAbstractItemModel's internal sort tracking)
        property int sortColumn: -1
        property int sortOrder: Qt.AscendingOrder

        // Mimics QAbstractItemModel::sort() from C++/Python
        // void sort(int column, Qt::SortOrder order = Qt::AscendingOrder)
        function sort(column, order) {
            if (order === undefined)
                order = Qt.AscendingOrder;

            // Store sort state
            sortColumn = column;
            sortOrder = order;

            // Get the role name for this column
            const roleName = columnRoles[column];
            if (!roleName) {
                console.warn("Invalid column for sorting:", column);
                return;
            }

            // Sort the rows array
            // Note: In SQL/Polars, this becomes: SELECT * FROM table ORDER BY column ASC/DESC
            let sortedRows = rows.slice();  // Copy to avoid binding issues
            sortedRows.sort((a, b) => {
                let aVal = a[roleName];
                let bVal = b[roleName];

                // Numeric comparison
                if (typeof aVal === 'number' && typeof bVal === 'number') {
                    return order === Qt.AscendingOrder ? aVal - bVal : bVal - aVal;
                }

                // String comparison (locale-aware)
                const comparison = String(aVal).localeCompare(String(bVal));
                return order === Qt.AscendingOrder ? comparison : -comparison;
            });

            // Update the model
            // In C++/Python: emit layoutAboutToBeChanged(), modify data, emit layoutChanged()
            rows = sortedRows;
        }

        // ========================================================================
        // ROW INSERTION: QML TableModel vs C++/Python QAbstractItemModel
        // ========================================================================
        // NOTE: Different insertRow() signatures between QML and QAbstractItemModel
        //
        // QML TableModel:
        //   insertRow(int rowIndex, object row) - takes DATA as 2nd parameter
        //   https://doc.qt.io/qt-6/qml-qt-labs-qmlmodels-tablemodel.html#insertRow-method
        //
        // C++/Python QAbstractItemModel:
        //   insertRow(int row, QModelIndex parent) - takes PARENT as 2nd parameter
        //   insertRows(int row, int count, QModelIndex parent) - NO data parameter at all
        //   https://doc.qt.io/qt-6/qabstractitemmodel.html#insertRow
        //   https://doc.qt.io/qtforpython-6/PySide6/QtCore/QAbstractItemModel.html#insertRows
        //
        // Qt Design: insertRows() creates empty slots, setData() populates them separately
        //
        // SOLUTION: We use custom methods (addRow/addRows) with a consistent API
        //
        // Example Python implementation:
        //
        //
        //  ```python
        //  def insertRows(
        //      self,
        //      row: int,
        //      count: int,
        //      parent: QModelIndex | QPersistentModelIndex = QModelIndex(),
        //  ) -> bool:
        //       # Qt standard virtual method - override this
        //       self.beginInsertRows(parent, row, row + count - 1)
        //       for i in range(count):
        //           self._data.insert(row + i, self._create_default_row())
        //       self.endInsertRows()
        //       return True
        //
        //   @Slot(int, result=bool)
        //   def addRow(self, row: int=-1):
        //       # Custom convenience wrapper
        //       if row < 0: row = len(self._data)
        //       return self.insertRows(row, 1)
        //  ```
        function addRow(row) {
            if (row === undefined || row < 0)
                row = rowCount;

            const defaultData = {
                name: `New Item ${rowCount + 1}`,
                color: "Blue",
                type: "Type A",
                age: 25,
                height: 170,
                weight: 70,
                speed: 50,
                origin: "North",
                pattern: "Solid",
                noise: "0.00"
            };

            insertRow(row, defaultData);
            return true;
        }

        // Insert multiple rows - convenience wrapper
        // Python (PySide6) equivalent:
        //   @Slot(int, int, result=bool)
        //   def addRows(self, row: int, count: int):
        //       # Custom convenience wrapper
        //       if row < 0: row = len(self._data)
        //       return self.insertRows(row, count)
        // Docs: https://doc.qt.io/qt-6/qabstractitemmodel.html#insertRows
        function addRows(row, count) {
            if (count === undefined)
                count = 1;
            if (row === undefined || row < 0)
                row = rowCount;

            for (let i = 0; i < count; i++) {
                addRow(row + i);
            }

            return true;
        }

        // ========================================================================
        // ROW REMOVAL: QML TableModel vs C++/Python QAbstractItemModel
        // ========================================================================
        // COMPATIBLE APIs (unlike insertRow which has incompatible signatures)
        //
        // QML TableModel:
        //   removeRow(int rowIndex, int count=1)
        //   https://doc.qt.io/qt-6/qml-qt-labs-qmlmodels-tablemodel.html#removeRow-method
        //
        // C++/Python QAbstractItemModel:
        //   removeRow(int row, QModelIndex parent) -> calls removeRows(row, 1, parent)
        //   removeRows(int row, int count, QModelIndex parent) - virtual method to override
        //   https://doc.qt.io/qt-6/qabstractitemmodel.html#removeRow
        //   https://doc.qt.io/qtforpython-6/PySide6/QtCore/QAbstractItemModel.html#removeRows
        //
        // COMPATIBILITY: When calling from QML with just a row index:
        //   QML TableModel: removeRow(5) -> removes 1 row at index 5
        //   Python model: removeRow(5) -> removeRows(5, 1, QModelIndex())
        // Both APIs are compatible when called from QML with a single row index.
    }
}
