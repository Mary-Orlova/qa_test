#!/bin/bash

# Скрипт интеграционного тестирования передачи файлов через TCP/UDP
# Проверяет:
# - Корректность передачи данных любого типа и размера
# - Сохранение целостности файлов
# - Обработку ошибок

set -euo pipefail  # Прерывать при ошибках, запрещать необъявленные переменные

readonly TEST_FILE="${1:-testfile.bin}"  # Переданный или создать новый файл
readonly RECEIVED_TCP="received_${TEST_FILE##*/}"  # Имя полученного файла (TCP)
readonly RECEIVED_UDP="received_${TEST_FILE##*/}"  # Имя полученного файла (UDP)
SERVER_PID=0  # PID серверного процесса
TCP_PORT=8080  # Порт TCP-сервера
UDP_PORT=9090  # Порт UDP-сервера
CHUNK_SIZE=1400  # Размер чанка для UDP

# Функция очистки ресурсов
cleanup() {
    echo "Очистка ресурсов..."
    # Безопасное завершение сервера
    [[ $SERVER_PID -gt 0 ]] && kill -SIGTERM "$SERVER_PID" 2>/dev/null || true
    # Удаление временных файлов
    rm -f "$RECEIVED_TCP" "$RECEIVED_UDP"
}

# Перехват сигналов для корректного завершения
trap cleanup EXIT INT TERM HUP

# Генерация тестового файла
generate_test_file() {
    local size_mb="${1:-4}"  # Размер в мегабайтах (по умолчанию 4MB)
    echo "Генерация тестового файла ${size_mb}MB..."
    dd if=/dev/urandom of="$TEST_FILE" bs=1M count="$size_mb" status=none
    echo "Контрольная сумма: $(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)"
}

# Ожидание доступности UDP-порта через отправку тестового пакета
wait_for_udp_port() {
    local port=$1
    local timeout=5
    local start_time=$(date +%s)

    echo "Проверка UDP-порта $port (отправка тестового пакета)..."

    while ! echo "PING" | nc -u -w1 localhost "$port" 2>/dev/null; do
        sleep 0.1
        if (( $(date +%s) - start_time > timeout )); then
            echo "Таймаут ожидания порта $port/udp"
            return 1
        fi
    done
}

# Тест TCP-передачи
test_tcp() {
    echo -e "\n=== Запуск TCP теста ==="

    # Запуск сервера в фоне
    python3 src/tcp_server.py &
    SERVER_PID=$!
    sleep 2  # Упрощенное ожидание инициализации сервера

    # Запуск клиента
    if ! python3 src/tcp_client.py "$TEST_FILE"; then
        echo "[ERROR] Ошибка TCP клиента"
        return 1
    fi

    # Верификация контрольных сумм
    local original_hash=$(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)
    local received_hash=$(shasum -a 256 "$RECEIVED_TCP" | cut -d' ' -f1)

    if [[ "$original_hash" != "$received_hash" ]]; then
        echo "[ERROR] Контрольные суммы не совпадают (TCP)"
        return 1
    fi

    echo "TCP тест пройден успешно"
    kill -SIGTERM "$SERVER_PID"
    wait "$SERVER_PID"
    SERVER_PID=0
}

# Тест UDP-передачи
test_udp() {
    echo -e "\n=== Запуск UDP теста ==="

    # Запуск сервера в фоне
    python3 src/udp_server.py &
    SERVER_PID=$!

    # Ожидание инициализации сервера
    wait_for_udp_port "$UDP_PORT" || return 1

    # Запуск клиента с указанием размера чанка
    if ! python3 src/udp_client.py "$TEST_FILE" "$CHUNK_SIZE"; then
        echo "[ERROR] Ошибка UDP клиента"
        return 1
    fi

    # Верификация контрольных сумм
    local original_hash=$(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)
    local received_hash=$(shasum -a 256 "$RECEIVED_UDP" | cut -d' ' -f1)

    if [[ "$original_hash" != "$received_hash" ]]; then
        echo "[ERROR] Контрольные суммы не совпадают (UDP)"
        return 1
    fi

    echo "UDP тест пройден успешно"
    kill -SIGTERM "$SERVER_PID"
    wait "$SERVER_PID"
    SERVER_PID=0
}

# Главная функция
main() {
    cd "$(dirname "$0")/.." || exit 1  # Переход в корень проекта

    # Создать тестовый файл, если не существует
    [[ ! -f "$TEST_FILE" ]] && generate_test_file "${2:-4}"  # Второй аргумент - размер в MB

    # Запуск тестов
    test_tcp
    test_udp

    echo -e "\nВсе тесты пройдены успешно!"
}

main "$@"
