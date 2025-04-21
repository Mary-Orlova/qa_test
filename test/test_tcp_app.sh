#!/bin/bash

# TCP-тест для передачи файлов
set -euo pipefail

readonly INPUT_FILE="${1:-}"  # Путь к файлу для теста
readonly TEST_FILE="${INPUT_FILE:-testfile.bin}"  # Использовать переданный или создать тестовый
readonly RECEIVED_FILE="received_${TEST_FILE##*/}"  # Имя полученного файла
SERVER_PID=0
TCP_PORT=8080

cleanup() {
    echo "Очистка ресурсов..."
    [[ $SERVER_PID -gt 0 ]] && kill -SIGTERM "$SERVER_PID" 2>/dev/null || true
    rm -f "$RECEIVED_FILE" "src/$TEST_FILE" "src/received_${TEST_FILE##*/}"
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
    local size_mb="${1:-4}"  # Дефолтный размер 4MB
    echo "Генерация тестового файла ${size_mb}MB..."
    dd if=/dev/urandom of="$TEST_FILE" bs=1M count="$size_mb" status=none
    echo "Контрольная сумма: $(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)"
}

wait_for_tcp_port() {
    local port=$1
    local timeout=5
    local start_time=$(date +%s)

    echo "Проверка TCP-порта $port..."

    while ! nc -z localhost "$port" 2>/dev/null; do
        sleep 0.1
        if (( $(date +%s) - start_time > timeout )); then
            echo "Таймаут ожидания порта $port/tcp"
            return 1
        fi
    done
}

test_tcp() {
    echo -e "\n=== Запуск TCP теста ==="

    # Копируем тестовый файл в директорию сервера
    cp "$TEST_FILE" "src/$TEST_FILE" || {
        echo "[ERROR] Не удалось скопировать файл в src/"
        return 1
    }

    # Запуск сервера в фоне (с SO_REUSEADDR)
    (cd src && python3 -c '
import socket, os, sys
sys.path.append(os.getcwd())
from tcp_server import main
main()
    ') &
    SERVER_PID=$!
    sleep 2  # Даем серверу время запуститься

    # Проверка порта
    if ! wait_for_tcp_port "$TCP_PORT"; then
        echo "[ERROR] Сервер не запустился"
        return 1
    fi

    # Запуск клиента (строго один раз)
    if ! (cd src && python3 tcp_client.py "$TEST_FILE"); then
        echo "[ERROR] Ошибка TCP клиента"
        return 1
    fi

    # Переносим полученный файл
    mv "src/received_$TEST_FILE" "$RECEIVED_FILE" || {
        echo "[ERROR] Не удалось переместить полученный файл"
        return 1
    }

    # Верификация
    local original_hash=$(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)
    local received_hash=$(shasum -a 256 "$RECEIVED_FILE" | cut -d' ' -f1)

    [[ "$original_hash" == "$received_hash" ]] || {
        echo "[ERROR] Контрольные суммы не совпадают"
        echo "Ожидалось: $original_hash"
        echo "Получено:  $received_hash"
        return 1
    }

    echo "TCP тест пройден успешно"
}

main() {
    cd "$(dirname "$0")/.." || exit 1

    check_input_file
    [[ -z "$INPUT_FILE" ]] && generate_test_file "${2:-4}"

    test_tcp
    echo -e "\nТест завершён. Проверьте файл: $RECEIVED_FILE"
}

main "$@"
