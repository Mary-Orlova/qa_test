"""
Модуль кастомной конфигурации логирования.
"""

import logging
from typing import Optional


def setup_custom_logger(
    name: str, log_file: Optional[str] = None, level: int = logging.INFO
) -> logging.Logger:
    """функция кастомной инициализации логгера."""
    logger = logging.getLogger(name)

    # Очистка предыдущих обработчиков
    if logger.hasHandlers():
        logger.handlers.clear()

    logger.setLevel(level)
    formatter = logging.Formatter(
        "[%(asctime)s] %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    # Консольный вывод
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    # Файловый вывод
    if log_file:
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)

    return logger
