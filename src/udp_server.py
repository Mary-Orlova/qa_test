"""UDP-сервер для загрузки файла любого размера и вида."""
import os
import socket
import sys
import time
from typing import Tuple

from logging_config import setup_custom_logger

logger = setup_custom_logger(__name__)

HOST = "127.0.0.1"  # Если есть не локальный адрес - изменить адрес хоста
PORT = 9090  # Если нужно открыть на другом порте - изменить адрес порта
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
        filename = filename.strip()  # Удаляем пробелы

        # Защита от пустых имен и мусорных данных
        if not filename or not all(c.isprintable() for c in filename):
            logger.error(f"Некорректное имя файла: '{filename}'")
            return

        # Проверка существования файла
        if not os.path.exists(filename):
            logger.error(f"Файл не найден: {filename}")
            sock.sendto(b"File not found", addr)
            return

        # Отправка данных
        with open(filename, "rb") as file:
            while True:
                chunk = file.read(BUFFER_SIZE)
                if not chunk:
                    sock.sendto(b"__EOF__", addr)
                    break

                # Защита от перегрузки сети
                try:
                    sock.sendto(chunk, addr)
                    time.sleep(0.001)  # Искусственная задержка
                except BlockingIOError:
                    logger.warning("Перегрузка сети - повторная отправка")
                    sock.sendto(chunk, addr)

        logger.info(f"Файл {filename} отправлен")
    except Exception as e:
        logger.error(f"Ошибка: {str(e)}", exc_info=True)


def main() -> None:
    """
    Функция запуска TCP сервера.
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server_socket:
            server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            server_socket.bind((HOST, PORT))
            logger.info(f"[UDP] Сервер запущен на {HOST}:{PORT}")

            while True:
                try:
                    data, addr = server_socket.recvfrom(BUFFER_SIZE)
                    filename = data.decode(errors='ignore').strip()  # Игнорируем некорректные символы

                    # Фильтрация мусорных данных
                    if not filename or filename == "X":
                        logger.warning(f"Получен пустой запрос от {addr}")
                        continue

                    handle_file_request(filename, server_socket, addr)
                except socket.timeout:
                    continue
    except KeyboardInterrupt:
        logger.info("Сервер остановлен")
        sys.exit(0)

if __name__ == "__main__":
    main()
