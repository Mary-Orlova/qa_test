"""UDP-сервер для загрузки файла любого размера и вида."""

import socket
from typing import Tuple

from .logging_config import setup_custom_logger

logger = setup_custom_logger(__name__)

HOST = "127.0.0.1"  # Если есть не локальный адрес - изменить адрес хоста
PORT = 8080  # Если нужно открыть на другом порте - изменить адрес порта
BUFFER_SIZE = 4096  #  Стандартная часть TCP данных, разделённая для эффективной обработки, хранения или передачи.


def handle_file_request(
    filename: str, sock: socket.socket, addr: Tuple[str, int]
) -> None:
    """
    Функция обработки запроса передачи файла.

    :param: filename: имя запрашиваемого файла
    :param: sock: UDP сокет сервера
    :param: addr: кортеж (ip, порт) клиента
    """
    try:
        with open(filename, "rb") as file:
            while True:
                chunk: bytes = file.read(BUFFER_SIZE)
                if not chunk:
                    sock.sendto(b"__EOF__", addr)
                    break
                sock.sendto(chunk, addr)
        logger.info(f"[UDP] Файл {filename} отправлен")
    except FileNotFoundError as error_not_found:
        logger.exception("Возникло исключение в handle_file_request", error_not_found)
        sock.sendto(b"File not found", addr)


def main() -> None:
    """
    Функция запуска TCP сервера.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server_socket:
        server_socket.bind((HOST, PORT))
        logger.info(f"[UDP] Сервер запущен на {HOST}:{PORT}")

        while True:
            data, addr = server_socket.recvfrom(BUFFER_SIZE)
            filename: str = data.decode()
            logger.info(f"[UDP] Запрос файла '{filename}' от {addr}")
            handle_file_request(filename, server_socket, addr)


if __name__ == "__main__":
    main()
