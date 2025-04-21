#!/bin/bash

# UDP-only тест
set -euo pipefail

readonly INPUT_FILE="${1:-}"  # Путь к файлу для теста
readonly TEST_FILE="${INPUT_FILE:-testfile.bin}"  # Исходный файл
readonly SERVER_FILE="${TEST_FILE##*/}"  # Имя файла на сервере (без пути)
readonly RECEIVED_FILE="received_${SERVER_FILE}"  # Имя полученного файла
SERVER_PID=0
UDP_PORT=9090 # для UDP

cleanup() {
    echo "Очистка ресурсов..."
    [[ $SERVER_PID -gt 0 ]] && kill -SIGTERM "$SERVER_PID" 2>/dev/null || true
    rm -f "$RECEIVED_FILE"
}

trap cleanup EXIT INT TERM HUP

check_input_file() {
    if [[ -n "$INPUT_FILE" ]]; then
        if [[ ! -f "$INPUT_FILE" ]]; then
            echo "[ERROR] Файл '$INPUT_FILE' не найден"
            exit 1
        fi
        echo "Используется файл: $INPUT_FILE"
        echo "Контрольная сумма: $(shasum -a 256 "$INPUT_FILE" | cut -d' ' -f1)"
    fi
}

generate_test_file() {
    local size_mb="${1:-4}"
    echo "Генерация тестового файла ${size_mb}MB..."
    dd if=/dev/urandom of="$TEST_FILE" bs=1M count="$size_mb" status=none
    echo "Контрольная сумма: $(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)"
}

wait_for_udp_port() {
    local port=$1
    local timeout=5
    local start_time=$(date +%s)

    echo "Проверка UDP-порта $port..."

    while ! nc -z -u localhost "$port" 2>/dev/null; do
        sleep 0.1
        if (( $(date +%s) - start_time > timeout )); then
            echo "Таймаут ожидания порта $port/udp"
            return 1
        fi
    done
}

test_udp() {
    echo -e "\n=== Запуск UDP теста ==="

    # Запуск сервера
    python3 src/udp_server.py &
    SERVER_PID=$!
    sleep 2

    # Проверка порта
    if ! wait_for_udp_port "$UDP_PORT"; then
        echo "[ERROR] Сервер не запустился"
        return 1
    fi

    # Запуск клиента (запрашиваем имя файла БЕЗ суффикса)
    if ! python3 src/udp_client.py "${SERVER_FILE}"; then
        echo "[ERROR] Ошибка UDP клиента"
        return 1
    fi

    # Верификация контрольных сумм
    local original_hash=$(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)
    local received_hash=$(shasum -a 256 "$RECEIVED_FILE" | cut -d' ' -f1)

    if [[ "$original_hash" != "$received_hash" ]]; then
        echo "[ERROR] Контрольные суммы не совпадают"
        echo "Ожидалось: $original_hash"
        echo "Получено:  $received_hash"
        return 1
    fi

    echo "UDP тест пройден успешно"
}

main() {
    cd "$(dirname "$0")/.." || exit 1

    check_input_file
    [[ -z "$INPUT_FILE" ]] && generate_test_file "${2:-4}"

    test_udp
    echo -e "\nТест завершён. Проверьте файл: $RECEIVED_FILE"
}

main "$@"
