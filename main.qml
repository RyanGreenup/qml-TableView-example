pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "qml"

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
                checked: editableTable.dragButtons === Qt.LeftButton
                onTriggered: editableTable.dragButtons = editableTable.dragButtons === Qt.NoButton ? Qt.LeftButton : Qt.NoButton
            }
            Action {
                text: "Enable &Resizing"
                shortcut: "Ctrl+R"
                checkable: true
                checked: editableTable.resizingEnabled
                onTriggered: editableTable.resizingEnabled = !editableTable.resizingEnabled
            }
            Action {
                text: "&Hide Headers"
                shortcut: "Ctrl+H"
                checkable: true
                checked: editableTable.hideHeaders
                onTriggered: editableTable.hideHeaders = !editableTable.hideHeaders
            }
            Action {
                text: "&Auto-Size Columns"
                shortcut: "Ctrl+A"
                checkable: true
                checked: editableTable.autoSizeColumns
                onTriggered: {
                    editableTable.autoSizeColumns = !editableTable.autoSizeColumns;
                    editableTable.forceLayout();
                }
            }
            Action {
                text: "Reset Column &Widths"
                shortcut: "Ctrl+Shift+R"
                onTriggered: {
                    editableTable.clearColumnWidths();
                    editableTable.forceLayout();
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
                    let insertPosition = editableTable.getSelectionModel().currentIndex.row;

                    // Use addRow() - custom method with C++/Python-compatible API
                    // This works identically when model is QML TableModel or C++/Python QAbstractTableModel
                    // See model's addRow() implementation for C++/Python migration examples
                    editableTable.getModel().addRow(insertPosition);
                }
            }
            Action {
                text: "Insert &Multiple Rows"
                shortcut: "Ctrl+Shift+N"
                onTriggered: {
                    // Insert before current row, or at end if no selection
                    let insertPosition = editableTable.getSelectionModel().currentIndex.row;

                    // Use addRows() - custom convenience method
                    // Inserts 3 rows with default data at the specified position
                    // See model's addRows() implementation for C++/Python migration examples
                    editableTable.getModel().addRows(insertPosition, 3);
                }
            }
            Action {
                text: "&Remove Current Row"
                shortcut: "Ctrl+Shift+D"
                enabled: editableTable.getSelectionModel().currentIndex.row >= 0
                onTriggered: {
                    let rowToRemove = editableTable.getSelectionModel().currentIndex.row;

                    // Use removeRow() - standard Qt method that works for both:
                    // - QML TableModel: removeRow(row, count=1) - returns undefined
                    // - C++/Python QAbstractTableModel: removeRow(row, parent) -> returns bool
                    let result = editableTable.getModel().removeRow(rowToRemove);

                    // Check for explicit failure (false), not undefined
                    // QML TableModel returns undefined, Python returns bool
                    if (result === false) {
                        console.error("[QML ERROR]: Failed to remove row", rowToRemove);
                    }
                }
            }
        }
    }

    EditableTable {
        id: editableTable
    }
}
