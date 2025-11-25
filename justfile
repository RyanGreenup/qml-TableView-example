



python-run:
    uv run -- python main.py

python-duckdb:
    uv run -- python main.py -m iris



# Python linting commands
python-lint: fmt
    uv run -- pyright

fmt:
    uv run --with ruff    -- ruff check --fix .
    uv run --with pyside6 -- pyside6-qmlformat -i  **/*.qml





# QML commands
qml-watch:
    qhot ./qml/EditableTable.qml
qml-lint:
    ./.venv/bin/pyside6-qmllint qml/*.qml ./main.qml
qml-run:
    # qml6 ./qml/EditableTable.qml
    uv run --with pyside6  pyside6-qml ./qml/EditableTable.qml
