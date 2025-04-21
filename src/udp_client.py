"""UDP-клиент получения файлов с сервера."""

import socket
import sys

from logging_config import setup_custom_logger

logger = setup_custom_logger(__name__)

HOST = "127.0.0.1"  # Если есть не локальный адрес - изменить адрес хоста
PORT = 9090  # Если нужно открыть на другом порте - изменить адрес порта
BUFFER_SIZE = 4096  #  Стандартная часть TCP данных, разделённая для эффективной обработки, хранения или передачи.


def receive_file(filename: str) -> bool:
    """
    UDP-функция получения файла.
    :param: filename: имя файла
    :param: bool: True при успешном получении, иначе False
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client_socket:
            client_socket.sendto(filename.encode(), (HOST, PORT))

            with open(f"received_{filename}", "wb") as file:
                while True:
                    data, addr = client_socket.recvfrom(BUFFER_SIZE)
                    if data == b"File not found":
                        logger.error("[ERROR] Файл не найден на сервере")
                        return False
                    if data == b"__EOF__":
                        break
                    file.write(data)

            logger.info(f"[SUCCESS] Сохранен  файл received_{filename}")
            return True
    except Exception as error:
        logger.exception(f"[ERROR] Возникло исключение в receive_file {error}")
        return False


def main() -> None:
    """
    Функция входа в приложение
    """

    # Проверка кол-ва аргументов командной строки, переданных скрипту.
    if len(sys.argv) != 2:
        logger.critical(
            "Использование: python udp_client.py не состоялось: Проверьте sys.argv"
        )
        sys.exit(1)

    success: bool = receive_file(sys.argv[1])
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
