"""TCP-клиент."""

import socket
import sys

from logging_config import setup_custom_logger

logger = setup_custom_logger(__name__)

HOST = "127.0.0.1"  # Если есть не локальный адрес - изменить адрес хоста
PORT = 8080  # Если нужно открыть на другом порте - изменить адрес порта
BUFFER_SIZE = 4096  #  Стандартная часть TCP данных, разделённая для эффективной обработки, хранения или передачи.


def request_file(filename: str) -> bool:
    """
    Функция запрашивает файл у сервера.
    :param filename: str
    :return: bool
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as client_socket:
            client_socket.connect((HOST, PORT))
            logger.debug(f"Подключено к серверу {HOST}:{PORT}")

            client_socket.sendall(filename.encode())
            initial_data: bytes = client_socket.recv(BUFFER_SIZE)

            if initial_data == b"File not found":
                logger.error(f"Файл {filename} не найден на сервере")
                return False

            with open(f"received_{filename}", "wb") as file:
                while True:
                    chunk: bytes = client_socket.recv(BUFFER_SIZE)
                    if not chunk:
                        break
                    file.write(chunk)

            logger.info(f"Файл получен и сохранен как received_{filename}")
            return True
    except Exception as e:
        logger.error(f"Ошибка при работе клиента: {str(e)}", exc_info=True)
        return False


def main() -> None:
    """
    Функция входа в приложение
    """

    # Проверка кол-ва аргументов командной строки, переданных скрипту.
    if len(sys.argv) != 2:
        logger.critical(
            "Использование: python tcp_client.py не состоялось:Проверьте sys.argv"
        )
        sys.exit(1)

    success: bool = request_file(sys.argv[1])
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
