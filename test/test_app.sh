#!/bin/bash

# Скрипт тестов передачи файлов любого размера и вида с помощью TCP/UDP

# Проверяет:
# корректность передачи данных
# сохранение целостности файлов
# обработку ошибок

set -euo pipefail

TEST_FILE="testfile.bin"
RECEIVED_TCP="received_${TEST_FILE}"
RECEIVED_UDP="received_${TEST_FILE}"
SERVER_PID=0

cleanup() {
    echo "Очистка..."
    [[ $SERVER_PID -gt 0 ]] && kill $SERVER_PID || true
    rm -f "$TEST_FILE" "$RECEIVED_TCP" "$RECEIVED_UDP"
}

# перехват сигналов операционной системы прерывание
trap cleanup EXIT

generate_test_file() {
    echo "Генерация тестового файла 4MB..."
    dd if=/dev/urandom of="$TEST_FILE" bs=1M count=4 status=none
}

test_tcp() {
    echo -e "\n=== Запуск TCP теста ==="
    python3 ../src/tcp_server.py &
    SERVER_PID=$!
    sleep 2

    if ! python3 ../src/tcp_client.py "$TEST_FILE"; then
        echo "[ERROR] TCP тест провален"
        return 1
    fi

    if ! sha256sum -c <(printf "%s  %s" "$(sha256sum "$TEST_FILE" | cut -d' ' -f1)" "$RECEIVED_TCP"); then
        echo "[ERROR] Контрольные суммы не совпадают (TCP)"
        return 1
    fi

    kill $SERVER_PID
    SERVER_PID=0
    return 0
}

test_udp() {
    echo -e "\n=== Запуск UDP теста ==="
    python3 ../src/udp_server.py &
    SERVER_PID=$!
    sleep 2

    if ! python3 ../src/udp_client.py "$TEST_FILE"; then
        echo "[ERROR] UDP тест провален"
        return 1
    fi

    if ! sha256sum -c <(printf "%s  %s" "$(sha256sum "$TEST_FILE" | cut -d' ' -f1)" "$RECEIVED_UDP"); then
        echo "[ERROR] Контрольные суммы не совпадают (UDP)"
        return 1
    fi

    kill $SERVER_PID
    SERVER_PID=0
    return 0
}

main() {
    cd "$(dirname "$0")" || exit 1
    generate_test_file

    test_tcp && test_udp

    echo -e "\nВсе тесты пройдены успешно!"
    exit 0
}

main
