#!/bin/bash

# Скрипт интеграционного тестирования передачи файлов через TCP/UDP
# Проверяет:
# - Корректность передачи данных
# - Сохранение целостности файлов
# - Обработку ошибок

set -euo pipefail

readonly TEST_FILE="testfile.bin"
readonly RECEIVED_TCP="received_${TEST_FILE}"
readonly RECEIVED_UDP="received_${TEST_FILE}"
SERVER_PID=0
TCP_PORT=8080  # Укажите реальный порт TCP
UDP_PORT=9090  # Укажите реальный порт UDP

cleanup() {
    echo "Очистка ресурсов..."
    if [[ $SERVER_PID -gt 0 ]]; then
        kill -SIGTERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    rm -f "$TEST_FILE" "$RECEIVED_TCP" "$RECEIVED_UDP"
}

trap cleanup EXIT INT TERM HUP

generate_test_file() {
    local size_mb=4
    echo "Генерация тестового файла ${size_mb}MB..."
    dd if=/dev/urandom of="$TEST_FILE" bs=1M count="$size_mb" status=none
    echo "Контрольная сумма: $(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)"
}

wait_for_port() {
    local port=$1
    local protocol=${2:-tcp}
    local timeout=5
    local start_time=$(date +%s)

    echo "Ожидание порта ${port}/${protocol}..."

    while ! nc -z -u "$protocol" localhost "$port" 2>/dev/null; do
        sleep 0.1
        if (( $(date +%s) - start_time > timeout )); then
            echo "Таймаут ожидания порта $port/$protocol"
            return 1
        fi
    done
}

test_tcp() {
    echo -e "\n=== Запуск TCP теста ==="

    python3 src/tcp_server.py &
    SERVER_PID=$!
    wait_for_port "$TCP_PORT" tcp || return 1

    if ! python3 src/tcp_client.py "$TEST_FILE"; then
        echo "[ERROR] Ошибка TCP клиента"
        return 1
    fi

    local original_hash=$(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)
    local received_hash=$(shasum -a 256 "$RECEIVED_TCP" | cut -d' ' -f1)

    if [[ "$original_hash" != "$received_hash" ]]; then
        echo "[ERROR] Контрольные суммы не совпадают (TCP)"
        echo "Ожидалось: $original_hash"
        echo "Получено:  $received_hash"
        return 1
    fi

    echo "TCP тест пройден успешно"
    kill -SIGTERM "$SERVER_PID"
    wait "$SERVER_PID"
    SERVER_PID=0
}

test_udp() {
    echo -e "\n=== Запуск UDP теста ==="

    python3 src/udp_server.py &
    SERVER_PID=$!
    wait_for_port "$UDP_PORT" udp || return 1

    if ! python3 src/udp_client.py "$TEST_FILE"; then
        echo "[ERROR] Ошибка UDP клиента"
        return 1
    fi

    local original_hash=$(shasum -a 256 "$TEST_FILE" | cut -d' ' -f1)
    local received_hash=$(shasum -a 256 "$RECEIVED_UDP" | cut -d' ' -f1)

    if [[ "$original_hash" != "$received_hash" ]]; then
        echo "[ERROR] Контрольные суммы не совпадают (UDP)"
        echo "Ожидалось: $original_hash"
        echo "Получено:  $received_hash"
        return 1
    fi

    echo "UDP тест пройден успешно"
    kill -SIGTERM "$SERVER_PID"
    wait "$SERVER_PID"
    SERVER_PID=0
}

main() {
    cd "$(dirname "$0")/.." || exit 1  # Переход в корень проекта
    generate_test_file
    test_tcp
    test_udp
    echo -e "\nВсе тесты пройдены успешно!"
}

main "$@"
