from pathlib import Path

# Variables to be replaced
vars_to_replace = [
    "tableModel",
    "dragButtons",
    "resizingEnabled",
    "hideHeaders",
    "autoSizeColumns",
    "headerBackgroundColor",
    "headerTextColor",
    "headerBorderColor",
    "cellBackgroundColor",
    "cellSelectedColor",
    "cellTextColor",
    "cellCurrentBorderColor",
    "tableFocusBorderColor",
    "tableBackgroundColor",
    "horizontalHeaderHeight",
    "horizontalHeaderBorderWidth",
    "verticalHeaderWidth",
    "verticalHeaderBorderWidth",
    "cellHeight",
    "cellBorderWidth",
    "cellPaddingHorizontal",
    "tableRowSpacing",
    "tableColumnSpacing",
    "tableFocusBorderWidth",
    "columnMinWidth",
    "columnMaxWidth",
    "columnDefaultWidth",
    "sortIndicatorFontSize",
    "headerTextSpacing",
]

# File path
filename = Path("./qml/EditableTable.qml")

# Read lines from file
with open(filename, "r") as fp:
    lines = fp.readlines()

id_val = "editableTableRoot"

# Replace occurrences and update lines
updated_lines = []
for line in lines:
    for var in vars_to_replace:
        # Construct replacement words
        from_word = f"tableContainer.{var}"
        to_word = f"{id_val}.{var}"
        # Replace in line if necessary
        if from_word in line:
            line = line.replace(from_word, to_word)
    updated_lines.append(line)

# Write updated lines back to the file
with open(filename, "w") as fp:
    fp.writelines(updated_lines)
