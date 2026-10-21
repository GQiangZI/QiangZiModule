#!/system/bin/sh
# common/settings.sh - 只保留 selfmount 开关

SETTINGS_FILE="${SETTINGS_FILE:-${MODDIR}/settings.conf}"

setting_get() {
    local key="$1" default="$2"
    [ "$key" = "selfmount" ] || { echo "$default"; return; }
    [ -f "$SETTINGS_FILE" ] || { echo "$default"; return; }
    local v
    v=$(grep -m1 "^selfmount=" "$SETTINGS_FILE" 2>/dev/null | cut -d= -f2-)
    case "$v" in 0|1) echo "$v" ;; *) echo "$default" ;; esac
}

setting_set() {
    local key="$1" value="$2"
    [ "$key" = "selfmount" ] || return 1
    case "$value" in 0|1) ;; *) return 1 ;; esac
    local tmp="${SETTINGS_FILE}.tmp"
    printf 'selfmount=%s\n' "$value" > "$tmp" 2>/dev/null || return 1
    mv "$tmp" "$SETTINGS_FILE" 2>/dev/null || return 1
    chmod 644 "$SETTINGS_FILE" 2>/dev/null
}

setting_init() {
    [ -f "$SETTINGS_FILE" ] && return 0
    local tmp="${SETTINGS_FILE}.tmp"
    printf 'selfmount=1\n' > "$tmp" 2>/dev/null || return 1
    mv "$tmp" "$SETTINGS_FILE" 2>/dev/null
    chmod 644 "$SETTINGS_FILE" 2>/dev/null
}