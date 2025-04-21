"""TCP-сервер для загрузки файла любого размера и вида."""

import os
import socket
from typing import Tuple

from logging_config import setup_custom_logger

logger = setup_custom_logger(__name__)

HOST = "127.0.0.1"  # Если есть не локальный адрес - изменить адрес хоста
PORT = 8080  # Если нужно открыть на другом порте - изменить адрес порта
BUFFER_SIZE = 4096  #  Стандартная часть TCP данных, разделённая для эффективной обработки, хранения или передачи.


def handle_client(conn: socket.socket, addr: Tuple[str, int]) -> None:
    """
     Функция обработки клиентское соединение.

    :param conn: объект подключенного сокета
    :param addr: кортеж (ip, порт) клиента
    :return: None
    """
    try:
        filename: str = conn.recv(BUFFER_SIZE).decode()
        logger.info(f"Запрос файла '{filename}' от {addr}")

        if not os.path.exists(filename):
            conn.sendall(b"File not found")
            logger.error(f"Файл не найден: {filename}")
            return

        with open(filename, "rb") as file:
            while True:
                chunk: bytes = file.read(BUFFER_SIZE)
                if not chunk:
                    break
                conn.sendall(chunk)
        logger.info(f"Файл {filename} успешно отправлен")
    except Exception as e:
        logger.error(f"Ошибка обработки клиента: {str(e)}", exc_info=True)
    finally:
        conn.close()


def main() -> None:
    """
    Функция запуска TCP сервера.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server_socket:
        server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server_socket.bind((HOST, PORT))
        server_socket.listen()
        logger.info(f"Сервер запущен на {HOST}:{PORT}")

        while True:
            conn, addr = server_socket.accept()
            logger.debug(f"Новое подключение от {addr}")
            handle_client(conn, addr)


if __name__ == "__main__":
    main()
