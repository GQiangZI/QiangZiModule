#!/system/bin/sh
MODDIR=${0%/*}
MODDIR=${MODDIR%/common}
. "$MODDIR/common/settings.sh"

case "$1" in
    get)  setting_get "$2" "${3:-}" ;;
    set)  if setting_set "$2" "$3"; then echo "OK"; else echo "FAIL"; exit 1; fi ;;
    dump) echo "selfmount=$(setting_get selfmount 1)" ;;
    *)    echo "Usage: $0 {get <key> [default]|set <key> <0|1>|dump}"; exit 1 ;;
esac