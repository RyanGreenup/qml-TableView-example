pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Qt.labs.qmlmodels

FocusScope {
    id: editableTableRoot
    visible: true
    anchors.fill: parent
    activeFocusOnTab: true

    // ========================================================================
    // PUBLIC API - Configuration Properties
    // ========================================================================

    // Data Model
    property alias tableModel: tableContainer.tableModel

    // ========================================================================
    // BEHAVIOR CONFIGURATION
    // ========================================================================
    property bool hideHeaders: false
    property bool resizingEnabled: true
    property int dragButtons: Qt.NoButton
    property bool autoSizeColumns: true
    property bool showRowNumbers: true

    // ========================================================================
    // FOCUS CONFIGURATION
    // ========================================================================
    // Whether to show the focus border when the table has active focus.
    // Set to false when the parent component (e.g., Card) provides its own focus indicator.
    property bool showFocusBorder: true
    // Whether to focus the table on hover
    property bool focusOnHover: false
    // Whether to focus the table when clicked
    property bool focusOnClick: true
    // Whether tab should focus next/previous widgets as is convention, or should move between cells
    // When keyNavigationEnabled is true, Tab will move cells instead of widgets, this overrides that
    property bool focusNavWithTab: true

    // ========================================================================
    // STYLING CONFIGURATION - Default Style Object
    // ========================================================================
    // Consumers can override individual properties or provide a complete style object
    property var style: QtObject {
        // Color Palette (Design Tokens)
        // Headers
        property color headerBackgroundColor: palette.button
        property color headerTextColor: palette.buttonText
        property color headerBorderColor: palette.mid
        property color headerHoverColor: Qt.rgba(0, 0, 0, 0.05)

        // Cells
        property color cellBackgroundColor: palette.base
        property color cellAlternateBackgroundColor: Qt.rgba(0, 0, 0, 0.02)
        property color cellSelectedColor: palette.highlight
        property color cellHoverColor: Qt.rgba(0, 0, 0, 0.03)
        property color cellTextColor: palette.text
        property color cellCurrentBorderColor: palette.highlight

        // Table
        // Focus border color - shown when table has activeFocus and showFocusBorder is true
        property color tableFocusBorderColor: palette.highlight
        property color tableBackgroundColor: "transparent"

        // Edit Field Styling
        property color editFieldBackgroundColor: palette.base
        property color editFieldBorderColor: palette.highlight
        property color editFieldTextColor: palette.text
        property int editFieldRadius: 4

        // Typography
        property int cellFontSize: 14
        property int cellTextAlignment: Text.AlignLeft  // Cell text alignment
        property int headerFontSize: 12
        property int headerFontWeight: Font.Medium
        property bool headerTextUppercase: false
        property int headerTextAlignment: Text.AlignLeft  // ShadCN uses left-aligned headers

        // Horizontal Header Styling
        property int horizontalHeaderHeight: 40
        property int horizontalHeaderBorderWidth: 0  // No side borders for clean look
        property int horizontalHeaderBottomBorderWidth: 2  // Strong bottom border (ShadCN style)
        property int horizontalHeaderPaddingHorizontal: 16  // Generous horizontal padding

        // Vertical Header Styling
        property int verticalHeaderMinWidth: 32  // Minimum width for row numbers
        property int verticalHeaderBorderWidth: 0  // No outer border
        property int verticalHeaderRightBorderWidth: 1  // Subtle right border to separate from content
        property int verticalHeaderPaddingHorizontal: 6  // Padding for row numbers
        property int verticalHeaderFontSize: 11  // Smaller, more subtle
        property int rowNumberTextAlignment: Text.AlignRight  // Right-align for better number alignment

        // Cell Styling
        property int cellHeight: 25
        property int cellBorderWidth: 2  // Border width for current cell
        property int cellPaddingHorizontal: 10
        property int cellPaddingVertical: 8
        property int cellRadius: 0  // Individual cell radius

        // Table Styling
        property int tableRowSpacing: 1
        property int tableColumnSpacing: 1
        property int tableFocusBorderWidth: 2
        property int tableRadius: 0  // Outer table border radius (0 for clean edges)

        // Behavior Flags
        property bool enableAlternatingRows: false
        property bool enableHoverEffects: true

        // Column Width Constraints (for auto-sizing)
        property int columnMinWidth: 60
        property int columnMaxWidth: 250
        property int columnDefaultWidth: 100

        // Header Sort Indicator
        property int sortIndicatorFontSize: 10
        property int headerTextSpacing: 4  // Spacing between header text and sort indicator
    }

    // ========================================================================
    // PUBLIC API - Methods
    // ========================================================================

    function clearColumnWidths() {
        tableView.clearColumnWidths();
    }

    function forceLayout() {
        tableView.forceLayout();
    }

    function getModel() {
        return tableView.model;
    }

    function getSelectionModel() {
        return tableView.selectionModel;
    }

    // Outer rectangle only handles the focus border
    Rectangle {
        id: focusBorder

        function getBorderColor() {
            let shouldShowBorder = editableTableRoot.showFocusBorder && editableTableRoot.activeFocus;
            if (shouldShowBorder) {
                return editableTableRoot.style.tableFocusBorderColor;
            }
            return "transparent";
        }

        color: "transparent"
        border.width: editableTableRoot.style.tableFocusBorderWidth
        border.color: getBorderColor()
        anchors.margins: editableTableRoot.style.tableFocusBorderWidth
        anchors.fill: parent

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }

        Rectangle {
            id: tableContainer
            objectName: "tableContainer"
            anchors.fill: parent
            anchors.margins: editableTableRoot.style.tableFocusBorderWidth
            color: "transparent"

            // ========================================================================
            // DATA MODEL CONFIGURATION
            // ========================================================================
            // The table model can be set from C++/Python or use the default example model.
            //
            // USAGE FROM C++/PYTHON:
            //   QML side:
            //     editableTableRoot.tableModel = myCustomModel
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
            //     - MUST be aliased to `addRow(self, row: int = -1)`
            //   - Custom Q_INVOKABLE methods - callable from QML (e.g., doSomethingWithCell)
            // ========================================================================
            property var tableModel: null  // Set to your C++/Python model, or null to use ExampleTableModel

            // Column Headers
            HorizontalHeaderView {
                id: hHeader
                clip: true
                anchors.top: parent.top
                anchors.left: editableTableRoot.showRowNumbers ? vHeader.right : parent.left
                anchors.right: parent.right
                syncView: tableView
                // Enables user column resizing (Qt 6.5+):
                // - Drag column border to manually resize
                // - Double-click column border to auto-fit to content
                // Resized widths are stored via setColumnWidth() and retrieved via explicitColumnWidth()
                // https://doc.qt.io/qt-6/qml-qtquick-tableview.html#resizableColumns-prop
                resizableColumns: editableTableRoot.resizingEnabled
                // qmllint disable missing-property
                acceptedButtons: editableTableRoot.dragButtons
                visible: !editableTableRoot.hideHeaders

                delegate: ColumnTitleTile {}
            }

            // Row Numbers
            VerticalHeaderView {
                id: vHeader
                clip: true

                // TODO clicking the Vertical HeaderView Steals focus from the Table
                focus: false
                focusPolicy: Qt.NoFocus

                anchors.top: hHeader.bottom
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                syncView: tableView
                resizableRows: editableTableRoot.resizingEnabled
                // qmllint disable missing-property
                acceptedButtons: editableTableRoot.dragButtons
                // Show row numbers only if: enabled AND headers not hidden
                visible: editableTableRoot.showRowNumbers && !editableTableRoot.hideHeaders

                delegate: RowNumberTile {}
            }

            // The table itself
            Rectangle {
                anchors.top: editableTableRoot.hideHeaders ? parent.top : hHeader.bottom
                anchors.left: {
                    // Priority: hideHeaders trumps showRowNumbers
                    if (editableTableRoot.hideHeaders) {
                        return parent.left;
                    }
                    // If headers visible, check if row numbers should be shown
                    return editableTableRoot.showRowNumbers ? vHeader.right : parent.left;
                }
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                color: editableTableRoot.style.tableBackgroundColor
                radius: editableTableRoot.style.tableRadius

                // Capture clicks on empty space to give focus to the table
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: {
                        if (editableTableRoot.focusOnClick) {
                            editableTableRoot.forceActiveFocus();
                        }
                    }
                }

                // Focus on hover handler
                HoverHandler {
                    enabled: editableTableRoot.focusOnHover
                    onHoveredChanged: {
                        if (hovered) {
                            editableTableRoot.forceActiveFocus();
                        }
                    }
                }

                TableView {
                    id: tableView
                    anchors.fill: parent
                    clip: true
                    interactive: true
                    // qmllint disable missing-property
                    acceptedButtons: editableTableRoot.dragButtons
                    rowSpacing: editableTableRoot.style.tableRowSpacing
                    columnSpacing: editableTableRoot.style.tableColumnSpacing
                    focus: true
                    editTriggers: TableView.DoubleTapped | TableView.EditKeyPressed

                    // Use custom model if provided, otherwise fallback to example model
                    model: editableTableRoot.tableModel ?? exampleModel
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

                        // TODO we need to handle long title names too
                        // If auto-sizing is enabled, use content-aware sizing
                        if (editableTableRoot.autoSizeColumns) {
                            let contentWidth = implicitColumnWidth(column);
                            return Math.min(Math.max(editableTableRoot.style.columnMinWidth, contentWidth), editableTableRoot.style.columnMaxWidth);
                        }

                        // Fallback to fixed width when auto-sizing is disabled
                        return editableTableRoot.style.columnDefaultWidth;
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

                        if (editableTableRoot.focusNavWithTab) {
                            if (event.key === Qt.Key_Tab) {
                                console.log("Tab Detected");
                                // Tab: move focus to next item
                                tableView.nextItemInFocusChain(true).forceActiveFocus();
                                event.accepted = true;
                            }
                            if (event.key === Qt.Key_Backtab) {
                                console.log("Shift+Tab (Backtab) Detected");
                                // Shift+Tab: move focus to previous item
                                tableView.nextItemInFocusChain(false).forceActiveFocus();
                                event.accepted = true;
                            }
                        }
                    }

                    delegate: TableCell {}
                    // Simple alternative:
                    // delegate: TableViewDelegate {}
                }
            }
        }
    }

    component TableCell: Rectangle {
        id: tableCell
        implicitHeight: editableTableRoot.style.cellHeight
        required property bool selected
        required property bool current
        required property bool editing
        required property var display
        required property int row
        required property int column

        // Calculate base color with alternating row support
        readonly property color baseColor: {
            if (editableTableRoot.style.enableAlternatingRows && row % 2 === 1) {
                return editableTableRoot.style.cellAlternateBackgroundColor;
            }
            return editableTableRoot.style.cellBackgroundColor;
        }

        // Determine cell background color based on state priority:
        // 1. Selected (highest priority)
        // 2. Hovered (if hover effects enabled)
        // 3. Base color (default, respects alternating rows)
        function getCellColor() {
            if (selected) {
                return editableTableRoot.style.cellSelectedColor;
            }
            if (cellMouseArea.containsMouse && editableTableRoot.style.enableHoverEffects) {
                return editableTableRoot.style.cellHoverColor;
            }
            return baseColor;
        }

        color: getCellColor()
        border.width: current ? editableTableRoot.style.cellBorderWidth : 0
        border.color: editableTableRoot.style.cellCurrentBorderColor
        radius: editableTableRoot.style.cellRadius
        clip: true

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        Label {
            id: cellLabel
            text: tableCell.display
            wrapMode: Text.Wrap
            anchors.fill: parent
            horizontalAlignment: editableTableRoot.style.cellTextAlignment
            verticalAlignment: Text.AlignVCenter
            leftPadding: editableTableRoot.style.cellPaddingHorizontal
            rightPadding: editableTableRoot.style.cellPaddingHorizontal
            topPadding: editableTableRoot.style.cellPaddingVertical
            bottomPadding: editableTableRoot.style.cellPaddingVertical
            visible: !tableCell.editing
            color: editableTableRoot.style.cellTextColor
            font.pixelSize: editableTableRoot.style.cellFontSize
        }

        // Set implicitWidth based on Label's content width + padding
        implicitWidth: cellLabel.implicitWidth + (editableTableRoot.style.cellPaddingHorizontal * 2)

        TableView.editDelegate: TextField {
            anchors.fill: parent
            required property var display
            required property int row
            required property int column
            text: display
            color: editableTableRoot.style.editFieldTextColor
            font.pixelSize: editableTableRoot.style.cellFontSize
            background: Rectangle {
                color: editableTableRoot.style.editFieldBackgroundColor
                border.color: editableTableRoot.style.editFieldBorderColor
                border.width: 2
                radius: editableTableRoot.style.editFieldRadius
            }
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
            id: cellMouseArea
            anchors.fill: parent
            hoverEnabled: editableTableRoot.style.enableHoverEffects
            onClicked: {
                let cellIndex = tableView.model.index(tableCell.row, tableCell.column);
                tableView.selectionModel.setCurrentIndex(cellIndex, ItemSelectionModel.ClearsAndSelects);

                if (editableTableRoot.focusOnClick) {
                    editableTableRoot.forceActiveFocus();
                }
            }
        }

        objectName: "root"
    }
    component RowNumberTile: Rectangle {
        id: verticalHeaderDelegate
        // Auto-size width based on text content + padding, with minimum width
        implicitWidth: Math.max(editableTableRoot.style.verticalHeaderMinWidth, rowNumberText.implicitWidth + (editableTableRoot.style.verticalHeaderPaddingHorizontal * 2))
        implicitHeight: editableTableRoot.style.cellHeight
        required property int index
        color: editableTableRoot.style.headerBackgroundColor
        border.width: editableTableRoot.style.verticalHeaderBorderWidth
        border.color: editableTableRoot.style.headerBorderColor
        focus: false
        focusPolicy: Qt.NoFocus

        // Subtle right border to separate from content (ShadCN style)
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: editableTableRoot.style.verticalHeaderRightBorderWidth
            color: editableTableRoot.style.headerBorderColor
            opacity: 0.5  // Very subtle
        }

        Text {
            id: rowNumberText
            focus: false
            focusPolicy: Qt.NoFocus
            anchors.fill: parent
            anchors.leftMargin: editableTableRoot.style.verticalHeaderPaddingHorizontal
            anchors.rightMargin: editableTableRoot.style.verticalHeaderPaddingHorizontal
            text: tableView.model.headerData(verticalHeaderDelegate.index, Qt.Vertical, Qt.DisplayRole) || ""
            font.pixelSize: editableTableRoot.style.verticalHeaderFontSize
            font.weight: Font.Normal  // Normal weight for subtlety
            color: editableTableRoot.style.headerTextColor
            horizontalAlignment: editableTableRoot.style.rowNumberTextAlignment
            verticalAlignment: Text.AlignVCenter
            opacity: 0.6  // Muted appearance
        }
    }

    component ColumnTitleTile: Rectangle {
        id: horizontalHeaderDelegate
        implicitWidth: editableTableRoot.style.columnDefaultWidth
        implicitHeight: editableTableRoot.style.horizontalHeaderHeight
        required property int index
        color: headerMouseArea.containsMouse && editableTableRoot.style.enableHoverEffects ? editableTableRoot.style.headerHoverColor : editableTableRoot.style.headerBackgroundColor
        border.width: editableTableRoot.style.horizontalHeaderBorderWidth
        border.color: editableTableRoot.style.headerBorderColor

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        // ShadCN-style bottom border
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: editableTableRoot.style.horizontalHeaderBottomBorderWidth
            color: editableTableRoot.style.headerBorderColor
        }

        // Content container with padding (ShadCN style: left-aligned with padding)
        Row {
            anchors.left: parent.left
            anchors.leftMargin: editableTableRoot.style.horizontalHeaderPaddingHorizontal
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: editableTableRoot.style.horizontalHeaderPaddingHorizontal
            spacing: editableTableRoot.style.headerTextSpacing

            Text {
                id: headerText
                text: {
                    let rawText = tableView.model.headerData(horizontalHeaderDelegate.index, Qt.Horizontal, Qt.DisplayRole) || "";
                    return editableTableRoot.style.headerTextUppercase ? rawText.toUpperCase() : rawText;
                }
                font.pixelSize: editableTableRoot.style.headerFontSize
                font.weight: editableTableRoot.style.headerFontWeight
                color: editableTableRoot.style.headerTextColor
                horizontalAlignment: editableTableRoot.style.headerTextAlignment
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.Wrap
                clip: true
                elide: Text.ElideRight
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
                font.pixelSize: editableTableRoot.style.sortIndicatorFontSize
                color: editableTableRoot.style.headerTextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: headerMouseArea
            anchors.fill: parent
            hoverEnabled: editableTableRoot.style.enableHoverEffects
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

    SelectionRectangle {
        target: tableView
    }

    // Default example model (used when editableTableRoot.tableModel is null)
    // This provides a self-contained demo and serves as documentation for
    // what a custom C++/Python model should implement
    ExampleTableModel {
        id: exampleModel
    }

    // This is an arbitrary data model that is good for testing
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
