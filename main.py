#!/usr/bin/env python3
from pathlib import Path
import sys
from enum import Enum
from typing import Annotated

import typer
from PySide6.QtCore import QObject
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

from tableModel import PythonTableModel
from irisTableModel import IrisTableModel
from postgresTableModel import PostgresTableModel

app_typer = typer.Typer()


class ModelType(str, Enum):
    python = "python"
    iris = "iris"
    postgres = "postgres"


@app_typer.command()
def main(
    model: Annotated[ModelType, typer.Option("--model", "-m")] = ModelType.python,
    db_path: Annotated[str, typer.Option("--db-path")] = "iris_data.duckdb",
):
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()

    # Create model
    if model == ModelType.iris:
        table_model = IrisTableModel(db_path=db_path)
    elif model == ModelType.postgres:
        table_model = PostgresTableModel()
    else:
        table_model = PythonTableModel()

    # Setup QML - expose model to QML context before loading
    engine.rootContext().setContextProperty("customTableModel", table_model)
    engine.load(Path("main.qml"))

    if not engine.rootObjects():
        sys.exit(-1)

    sys.exit(app.exec())


if __name__ == "__main__":
    app_typer()
