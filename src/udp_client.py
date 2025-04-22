"""UDP-клиент для загрузки файла."""
import socket
import sys
from logging_config import setup_custom_logger

logger = setup_custom_logger(__name__)

HOST = "127.0.0.1"  # Должен совпадать с серверным
PORT = 9090  # Порт должен совпадать с серверным
BUFFER_SIZE = 4096  # Размер буфера


def receive_file(sock: socket.socket, filename: str) -> None:
    """Получение файла от сервера."""
    received_filename = f"received_{filename}"
    try:
        with open(received_filename, "wb") as file:
            while True:
                data, _ = sock.recvfrom(BUFFER_SIZE)
                if data == b"__EOF__":
                    break
                file.write(data)
        logger.info(f"Файл получен: {received_filename}")
    except Exception as e:
        logger.error(f"Ошибка получения файла: {str(e)}")
        raise


def main() -> None:
    """Основная функция клиента."""
    if len(sys.argv) != 2:
        logger.critical("Требуется имя файла: python udp_client.py <filename>")
        sys.exit(1)

    filename = sys.argv[1].strip()  # Удаляем пробелы
    if not filename:  # Защита от пустых имен
        logger.critical("Имя файла не может быть пустым")
        sys.exit(1)

    logger.info(f"Запрос файла: {filename}")

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.settimeout(5.0)

            # Отправляем имя файла (кодируем строку!)
            sock.sendto(filename.encode(), (HOST, PORT))

            # Принимаем файл
            receive_file(sock, filename)
    except socket.timeout:
        logger.error("Таймаут ожидания данных от сервера")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Критическая ошибка: {str(e)}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
