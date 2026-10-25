#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
ICON="$(realpath "$SCRIPT_DIR/../../assets/icons/qr_code_scanner.svg")"

IMAGE="$1"

if [ -z "$IMAGE" ]; then
    exit 1
fi

if ! command -v zbarimg >/dev/null 2>&1; then
    notify-send -a "QR Reader" -i "$ICON" "QR Reader" "Install zbar (zbarimg) to scan QR codes"
    rm -f "$IMAGE"
    exit 1
fi

decoded_output=$(zbarimg --raw -q "$IMAGE" 2>/dev/null)
rm -f "$IMAGE"

if [ -z "$decoded_output" ]; then
    notify-send -a "QR Reader" -i "$ICON" "QR Reader" "No QR code found in the selected region"
    exit 0
fi

printf '%s' "$decoded_output" | wl-copy

