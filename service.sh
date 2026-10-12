#!/system/bin/sh
# service.sh - 生成 WebUI 状态 + 媒体扫描
#   - 源路径: $MODDIR/system/product/media/audio
#   - 无源文件的分类自动跳过索引
#   - 闹钟、铃声、通知音全索引；UI 不进 MediaStore
#   - 详细日志

MODDIR=${0%/*}
LOGFILE="$MODDIR/service.log"

if [ -f "$LOGFILE" ] && [ "$(wc -l < "$LOGFILE" 2>/dev/null)" -gt 3000 ]; then
    tail -n 1000 "$LOGFILE" > "$LOGFILE.tmp" 2>/dev/null && mv "$LOGFILE.tmp" "$LOGFILE"
fi

log() {
    echo "[$(date '+%m-%d %H:%M:%S')] [svc] $*" >> "$LOGFILE"
}

log "════════════════════════════════════════"
log "=== service.sh 启动 (v2.0) ==="

HAS_CONTENT=0
command -v content >/dev/null 2>&1 && HAS_CONTENT=1
log "content CLI: $([ "$HAS_CONTENT" = "1" ] && echo 可用 || echo 不可用)"

WAIT=0
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 1
    WAIT=$((WAIT + 1))
    if [ "$WAIT" -ge 120 ]; then
        log "!! 等待 boot_completed 超时（120s），继续"
        break
    fi
done
sleep 3
log "开机完成, 等待 ${WAIT}s"

# ═══════════════════════════════════════════
# 读取 module.prop
# ═══════════════════════════════════════════
MODULE_ID=$(grep -m1 '^id='          "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2-)
MODULE_NAME=$(grep -m1 '^name='      "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2-)
MODULE_VER=$(grep -m1 '^version='    "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2-)
MODULE_VCODE=$(grep -m1 '^versionCode=' "$MODDIR/module.prop" 2>/dev/null | cut -d= -f2-)

[ -z "$MODULE_ID" ]    && MODULE_ID="Hyperos_audio_core"
[ -z "$MODULE_NAME" ]  && MODULE_NAME="小米音效定制模块"
[ -z "$MODULE_VER" ]   && MODULE_VER="2.0"
[ -z "$MODULE_VCODE" ] && MODULE_VCODE="2"

log "模块: $MODULE_NAME $MODULE_VER"
# ═══════════════════════════════════════════
# 元模块检测
# ═══════════════════════════════════════════
META_STATUS="false"
META_NAME=""
if [ -d "/data/adb/metamodule" ]; then
    META_STATUS="true"; META_NAME="MetaModule"
elif [ -d "/data/adb/modules/meta-overlayfs" ]; then
    META_STATUS="true"; META_NAME="meta-overlayfs"
elif [ -d "/data/adb/modules/hybrid_mount" ]; then
    META_STATUS="true"; META_NAME="hybrid_mount"
elif [ -d "/data/adb/modules/mountify" ]; then
    META_STATUS="true"; META_NAME="mountify"
elif [ -d "/data/adb/modules/magic_mount" ] || [ -d "/data/adb/modules/Magic_Mount" ]; then
    META_STATUS="true"; META_NAME="Magic Mount"
else
    # 看挂载表里有没有元模块的 overlay
    if mount 2>/dev/null | grep -qE "overlay.*(/data/adb/modules|/data/adb/metamodule)"; then
        META_STATUS="true"; META_NAME="Unknown"
    fi
fi

log "元模块: $META_STATUS ($META_NAME)"
# ═══════════════════════════════════════════
# 源路径
# ═══════════════════════════════════════════
AUDIO_SRC="$MODDIR/system/product/media/audio"

# ═══════════════════════════════════════════
# 扫描音效文件
# ═══════════════════════════════════════════
scan_audio_dir() {
    local dir="$1" result=""
    [ -d "$dir" ] || { echo ""; return; }
    for f in "$dir"/*; do
        [ -f "$f" ] || continue
        local name="${f##*/}"
        local ext="${name##*.}"
        ext=$(echo "$ext" | tr 'A-Z' 'a-z')
        case "$ext" in
            ogg|mp3|wav|m4a|aac|flac)
                [ -n "$result" ] && result="$result,"
                result="$result\"$name\""
                ;;
        esac
    done
    echo "$result"
}

ALARM_LIST=$(scan_audio_dir "$AUDIO_SRC/alarms")
NOTIF_LIST=$(scan_audio_dir "$AUDIO_SRC/notifications")
RING_LIST=$(scan_audio_dir  "$AUDIO_SRC/ringtones")
UI_LIST=$(scan_audio_dir    "$AUDIO_SRC/ui")

count_files() {
    [ -z "$1" ] && { echo 0; return; }
    echo "$1" | tr ',' '\n' | wc -l | tr -d ' '
}
TOTAL=$(( $(count_files "$ALARM_LIST") + $(count_files "$NOTIF_LIST") + \
         $(count_files "$RING_LIST") + $(count_files "$UI_LIST") ))

log "文件统计: 闹钟=$(count_files "$ALARM_LIST") 通知=$(count_files "$NOTIF_LIST") 铃声=$(count_files "$RING_LIST") UI=$(count_files "$UI_LIST")"

# ═══════════════════════════════════════════
# 挂载状态检测
# ═══════════════════════════════════════════
check_mount() {
    local src_dir="$1" dst_dir="$2" count=0 total=0
    [ -d "$src_dir" ] || { echo "false"; return; }
    for f in "$src_dir"/*; do
        [ -f "$f" ] || continue
        total=$((total + 1))
        local fname="${f##*/}"
        local src_ino dst_ino
        src_ino=$(stat -c %i "$f" 2>/dev/null)
        dst_ino=$(stat -c %i "$dst_dir/$fname" 2>/dev/null)
        [ -n "$src_ino" ] && [ "$src_ino" = "$dst_ino" ] && count=$((count + 1))
    done
    if [ "$total" -gt 0 ] && [ "$count" -gt $((total / 2)) ]; then
        log "  挂载检测 $dst_dir: $count/$total ✓"
        echo "true"
    else
        log "  挂载检测 $dst_dir: $count/$total ✗"
        echo "false"
    fi
}

MOUNT_ALARM=$(check_mount "$AUDIO_SRC/alarms"        "/product/media/audio/alarms")
MOUNT_NOTIF=$(check_mount "$AUDIO_SRC/notifications" "/product/media/audio/notifications")
MOUNT_RING=$(check_mount  "$AUDIO_SRC/ringtones"     "/product/media/audio/ringtones")
MOUNT_UI=$(check_mount    "$AUDIO_SRC/ui"            "/product/media/audio/ui")

log "挂载状态: 闹钟=$MOUNT_ALARM 通知=$MOUNT_NOTIF 铃声=$MOUNT_RING UI=$MOUNT_UI"

# ═══════════════════════════════════════════
# MediaStore 索引
# ═══════════════════════════════════════════
get_mime() {
    case "$1" in
        ogg) echo "audio/ogg" ;;
        mp3) echo "audio/mpeg" ;;
        wav) echo "audio/x-wav" ;;
        m4a|aac) echo "audio/mp4" ;;
        flac) echo "audio/flac" ;;
        *) echo "" ;;
    esac
}

in_mediastore() {
    local path="$1"
    [ "$HAS_CONTENT" = "1" ] || return 1
    local safe
    safe=$(printf '%s' "$path" | sed "s/'/''/g")
    content query --uri content://media/internal/audio/media \
        --projection _data --where "_data='$safe'" 2>/dev/null | grep -qF "$path"
}

wait_for_index() {
    local path="$1" tries=0
    while [ "$tries" -lt 5 ]; do
        in_mediastore "$path" && return 0
        sleep 0.3
        tries=$((tries + 1))
    done
    return 1
}

scan_and_index() {
    local category="$1" dst_dir="$2"
    local flag_name=""
    case "$category" in
        alarms)        flag_name="is_alarm" ;;
        notifications) flag_name="is_notification" ;;
        ringtones)     flag_name="is_ringtone" ;;
        *) log "  索引[$category]: 跳过"; return ;;
    esac

    [ "$HAS_CONTENT" = "1" ] || { log "  索引[$category]: content 不可用，跳过"; return; }
    [ -d "$dst_dir" ]        || { log "  索引[$category]: 目标不存在"; return; }

    local skip=0 scan_ok=0 insert_ok=0 fail=0
    for f in "$dst_dir"/*; do
        [ -f "$f" ] || continue
        local fname="${f##*/}"
        local ext="${fname##*.}"; ext=$(echo "$ext" | tr 'A-Z' 'a-z')
        local mime; mime=$(get_mime "$ext")
        local fullpath="$dst_dir/$fname"

        if in_mediastore "$fullpath"; then
            skip=$((skip + 1)); continue
        fi

        am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
            -d "file://$fullpath" >/dev/null 2>&1

        if wait_for_index "$fullpath"; then
            scan_ok=$((scan_ok + 1))
            log "    索引[$category]: $fname 广播 ✓"
            continue
        fi

        if [ -n "$mime" ]; then
            content insert --uri content://media/internal/audio/media \
                --bind _data:s:"$fullpath" \
                --bind title:s:"$fname" \
                --bind mime_type:s:"$mime" \
                --bind "$flag_name":i:1 \
                --bind is_alarm:i:0 \
                --bind is_music:i:0 \
                >/dev/null 2>&1
            if wait_for_index "$fullpath"; then
                insert_ok=$((insert_ok + 1))
                log "    索引[$category]: $fname insert ✓"
            else
                fail=$((fail + 1))
                log "    索引[$category]: $fname insert ✗"
            fi
        else
            fail=$((fail + 1))
            log "    索引[$category]: $fname 格式不支持 ($ext)"
        fi
    done
    log "  索引[$category]: 已索引=$skip 扫描=$scan_ok insert=$insert_ok 失败=$fail"
}

# 清除 MediaStore 记录
if [ "$HAS_CONTENT" = "1" ]; then
    log "清除 MediaStore 中本模块记录"
    content delete --uri content://media/internal/audio/media \
        --where "_data LIKE '/product/media/audio/%'" >/dev/null 2>&1
fi

# 扫描（无源文件的分类跳过）
log "开始 MediaStore 索引"
for cat in alarms notifications ringtones; do
    if [ -d "$AUDIO_SRC/$cat" ] && [ "$(ls -1 "$AUDIO_SRC/$cat" 2>/dev/null | wc -l)" -gt 0 ]; then
        scan_and_index "$cat" "/product/media/audio/$cat"
    else
        log "  索引[$cat]: 模块无源文件，跳过"
    fi
done
# UI 不进 MediaStore

# ═══════════════════════════════════════════
# 生成 WebUI 状态
# ═══════════════════════════════════════════
[ -d "$MODDIR/webroot" ] || mkdir -p "$MODDIR/webroot"

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

MODEL=$(getprop ro.product.marketname 2>/dev/null)
[ -z "$MODEL" ] && MODEL=$(getprop ro.product.model 2>/dev/null)
[ -z "$MODEL" ] && MODEL="Unknown"

SDK=$(getprop ro.build.version.sdk 2>/dev/null)
ANDROID=$(getprop ro.build.version.release 2>/dev/null)
KERNEL=$(uname -r 2>/dev/null | head -n1 | tr -d '\r\n')
KSU_VER=$(ksud --version 2>/dev/null | head -n1 | tr -d '\r\n')
[ -z "$SDK" ]     && SDK="Unknown"
[ -z "$ANDROID" ] && ANDROID="Unknown"
[ -z "$KERNEL" ]  && KERNEL="N/A"
[ -z "$KSU_VER" ] && KSU_VER="N/A"

MODEL_E=$(json_escape "$MODEL")
ANDROID_E=$(json_escape "Android $ANDROID (SDK $SDK)")
KERNEL_E=$(json_escape "$KERNEL")
KSU_VER_E=$(json_escape "KernelSU $KSU_VER")
MODULE_NAME_E=$(json_escape "$MODULE_NAME")
MODULE_VER_E=$(json_escape "$MODULE_VER")

case "$MODULE_VER_E" in
    v*|V*) MODULE_VER_DISPLAY="$MODULE_VER_E" ;;
    *)     MODULE_VER_DISPLAY="v$MODULE_VER_E" ;;
esac

log "型号: $MODEL"

# status.js
tmp_js="$MODDIR/webroot/status.js.tmp"
cat > "$tmp_js" << EOF
const MODULE_STATUS = {
  name: "$MODULE_NAME_E",
  version: "$MODULE_VER_E",
  versionDisplay: "$MODULE_VER_DISPLAY",
  versionCode: ${MODULE_VCODE:-0},
  id: "$MODULE_ID",
  model: "$MODEL_E",
  android: "$ANDROID_E",
  kernel: "$KERNEL_E",
  root: "$KSU_VER_E",
  metaModule: $META_STATUS,
  mount: {
    alarms: $MOUNT_ALARM,
    notifications: $MOUNT_NOTIF,
    ringtones: $MOUNT_RING,
    ui: $MOUNT_UI
  },
  files: {
    alarms: [$ALARM_LIST],
    notifications: [$NOTIF_LIST],
    ringtones: [$RING_LIST],
    ui: [$UI_LIST]
  }
};
EOF
mv "$tmp_js" "$MODDIR/webroot/status.js" 2>/dev/null

# webui_status.json
tmp_json="$MODDIR/webroot/webui_status.json.tmp"
cat > "$tmp_json" << EOF
{
  "name": "$MODULE_NAME_E",
  "version": "$MODULE_VER_E",
  "versionDisplay": "$MODULE_VER_DISPLAY",
  "versionCode": ${MODULE_VCODE:-0},
  "id": "$MODULE_ID",
  "model": "$MODEL_E",
  "android": "$ANDROID_E",
  "kernel": "$KERNEL_E",
  "root": "$KSU_VER_E",
  "metaModule": $META_STATUS,
  "mount": {
    "alarms": $MOUNT_ALARM,
    "notifications": $MOUNT_NOTIF,
    "ringtones": $MOUNT_RING,
    "ui": $MOUNT_UI
  },
  "files": {
    "alarms": [$ALARM_LIST],
    "notifications": [$NOTIF_LIST],
    "ringtones": [$RING_LIST],
    "ui": [$UI_LIST]
  }
}
EOF
mv "$tmp_json" "$MODDIR/webroot/webui_status.json" 2>/dev/null

log "WebUI 状态已更新 (共 $TOTAL 个音效)"
log "=== service.sh 完成 ==="
exit 0