#!/system/bin/sh
# service.sh - 系统启动后执行：生成 WebUI 状态 + 媒体扫描
MODDIR=${0%/*}
LOGFILE="$MODDIR/service.log"
MODULE_ID="Hyperos_audio_core"
METAMOD_DIR="/data/adb/metamodule/mnt/$MODULE_ID"

log() {
    mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null
    echo "[$(date '+%H:%M:%S')] [service] $*" >> "$LOGFILE"
}

# 等待开机完成
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 1; done
sleep 3

log "=== service.sh 启动 ==="

# ── 元模块同步 ──
if [ -d "/data/adb/metamodule" ] && [ -d "$MODDIR/system/product/media/audio" ]; then
    mkdir -p "$METAMOD_DIR/system/product/media/audio" 2>/dev/null
    for category in notifications ringtones ui; do
        src="$MODDIR/system/product/media/audio/$category"
        dst="$METAMOD_DIR/system/product/media/audio/$category"
        [ -d "$src" ] || continue
        mkdir -p "$dst" 2>/dev/null
        for f in "$src"/*; do
            [ -f "$f" ] || continue
            cp -f "$f" "$dst/$(basename "$f")" 2>/dev/null
        done
    done
    # 修正元模块副本的 SELinux 标签（cp 到 /data 后 context 非 system_file，audioserver 会拒读）
    chcon -R u:object_r:system_file:s0 "$METAMOD_DIR/system/product/media/audio" 2>/dev/null
    log "元模块同步完成"
else
    log "元模块未安装，跳过同步"
fi

# ── 扫描音效文件 ──
scan_audio_dir() {
    local dir="$1" result=""
    [ -d "$dir" ] || { echo ""; return; }
    for f in "$dir"/*; do
        [ -f "$f" ] || continue
        local name=$(basename "$f")
        local ext=$(echo "${name##*.}" | tr '[:upper:]' '[:lower:]')
        case "$ext" in
            ogg|mp3|wav|m4a|aac|flac)
                [ -n "$result" ] && result="$result,"
                result="$result\"$name\""
                ;;
        esac
    done
    echo "$result"
}

NOTIF_LIST=$(scan_audio_dir "$MODDIR/system/product/media/audio/notifications")
RING_LIST=$(scan_audio_dir "$MODDIR/system/product/media/audio/ringtones")
UI_LIST=$(scan_audio_dir "$MODDIR/system/product/media/audio/ui")

count_files() {
    [ -z "$1" ] && { echo 0; return; }
    echo "$1" | tr ',' '\n' | wc -l | tr -d ' '
}
TOTAL=$(( $(count_files "$NOTIF_LIST") + $(count_files "$RING_LIST") + $(count_files "$UI_LIST") ))

# ── 检测挂载状态（查 /product/media/audio/，HyperOS 实际路径） ──
check_mount() {
    local src_dir="$1" dst_dir="$2" count=0 total=0
    [ -d "$src_dir" ] || { echo "false"; return; }
    for f in "$src_dir"/*; do
        [ -f "$f" ] || continue
        total=$((total + 1))
        local fname=$(basename "$f")
        if [ -f "$dst_dir/$fname" ] && [ -s "$dst_dir/$fname" ]; then
            count=$((count + 1))
        fi
    done
    if [ "$total" -gt 0 ] && [ "$count" -gt $((total / 2)) ]; then
        log "挂载检测: $dst_dir → $count/$total ✓"
        echo "true"
    else
        log "挂载检测: $dst_dir → $count/$total ✗"
        echo "false"
    fi
}

MOUNT_NOTIF=$(check_mount "$MODDIR/system/product/media/audio/notifications" "/product/media/audio/notifications")
MOUNT_RING=$(check_mount "$MODDIR/system/product/media/audio/ringtones" "/product/media/audio/ringtones")
MOUNT_UI=$(check_mount "$MODDIR/system/product/media/audio/ui" "/product/media/audio/ui")
log "挂载状态: 通知=$MOUNT_NOTIF 铃声=$MOUNT_RING UI=$MOUNT_UI"

# ── 元模块状态 ──
META_STATUS="false"
[ -d "$METAMOD_DIR/system/product/media/audio" ] && META_STATUS="true"

# ── 逐文件媒体扫描 + MediaStore 兜底插入 ──
# 原理（基于 AOSP 框架源码）：
#   * MediaScanner 按父目录名判定类型，只扫直接子文件（非递归）
#   * 新文件放入后不会自动索引，必须触发扫描或直接写 MediaStore
#   * 广播失败时用 content insert 强制注册，绕过扫描层

get_mime() {
    case "$1" in
        ogg)  echo "audio/ogg" ;;
        mp3)  echo "audio/mpeg" ;;
        wav)  echo "audio/x-wav" ;;
        m4a|aac) echo "audio/mp4" ;;
        flac) echo "audio/flac" ;;
        *)    echo "" ;;
    esac
}

# 检查文件是否已被 MediaStore 索引（区分扫描层/展示层问题）
in_mediastore() {
    local path="$1"
    content query --uri content://media/internal/audio/media --projection _data --where "_data='$path'" 2>/dev/null | grep -qF "$path"
}

scan_and_index() {
    local category="$1" dst_dir="$2"
    [ -d "$dst_dir" ] || { log "索引[$category]: 目标目录不存在 $dst_dir"; return; }
    local skip=0 scan_ok=0 insert_ok=0 fail=0
    for f in "$dst_dir"/*; do
        [ -f "$f" ] || continue
        local fname=$(basename "$f")
        local ext=$(echo "${fname##*.}" | tr '[:upper:]' '[:lower:]')
        local mime=$(get_mime "$ext")
        local fullpath="$dst_dir/$fname"

        # ① 已在 MediaStore 直接跳过
        if in_mediastore "$fullpath"; then
            skip=$((skip+1)); continue
        fi

        # ② 单文件广播触发扫描
        am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d "file://$fullpath" >/dev/null 2>&1
        sleep 1
        if in_mediastore "$fullpath"; then
            scan_ok=$((scan_ok+1))
            log "索引[$category]: $fname 广播扫描成功 ✓"
            continue
        fi

        # ③ MediaStore 兜底插入（绕过扫描层，终极方案）
        if [ -n "$mime" ]; then
            content insert --uri content://media/internal/audio/media \
                --bind _data:s:"$fullpath" \
                --bind title:s:"$fname" \
                --bind mime_type:s:"$mime" >/dev/null 2>&1
            sleep 1
            if in_mediastore "$fullpath"; then
                insert_ok=$((insert_ok+1))
                log "索引[$category]: $fname 兜底插入成功 ✓"
            else
                fail=$((fail+1))
                log "索引[$category]: $fname 插入失败 ✗ (mime=$mime) → 白名单可能在展示层"
            fi
        else
            fail=$((fail+1))
            log "索引[$category]: $fname 不支持的格式 ✗ (ext=$ext)"
        fi
    done
    log "索引[$category]: 已索引=$skip 扫描成功=$scan_ok 兜底插入=$insert_ok 失败=$fail"
}

scan_and_index "notifications" "/product/media/audio/notifications"
scan_and_index "ringtones" "/product/media/audio/ringtones"
# ⚠️ UI 音效（锁屏/解锁/充电/低电量）由系统按固定路径直接播放，不需要 MediaStore 索引
# v8.1 曾对 ui 做 content insert（未带类型标志），导致系统播放 URI 解析异常、UI 音效失效
# 已还原 v8.0 行为：UI 目录不进 MediaStore

# ── 白名单层级诊断 ──
DIAG_NOTIF=$(content query --uri content://media/internal/audio/media --projection _data --where "is_notification=1" 2>/dev/null | wc -l)
DIAG_RING=$(content query --uri content://media/internal/audio/media --projection _data --where "is_ringtone=1" 2>/dev/null | wc -l)
log "MediaStore 诊断: 通知音记录=$DIAG_NOTIF 铃声记录=$DIAG_RING (0条=扫描层白名单, >0但不显示=展示层白名单)"

# ── 生成 WebUI 状态 ──
MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo "Unknown")
ANDROID=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
KERNEL=$(uname -r 2>/dev/null || echo "N/A")
KSU_VER=$(ksud --version 2>/dev/null || echo "N/A")

cat > "$MODDIR/webroot/status.js" << EOF
const MODULE_STATUS = {
  model: "$MODEL",
  android: "Android $ANDROID (SDK $SDK)",
  kernel: "$KERNEL",
  root: "KernelSU $KSU_VER",
  mountEnabled: true,
  conflict: false,
  metaModule: $META_STATUS,
  mount: {
    notifications: $MOUNT_NOTIF,
    ringtones: $MOUNT_RING,
    ui: $MOUNT_UI
  },
  files: {
    notifications: [$NOTIF_LIST],
    ringtones: [$RING_LIST],
    ui: [$UI_LIST]
  }
};
EOF
cp -f "$MODDIR/webroot/status.js" "$MODDIR/webroot/webui_status.json" 2>/dev/null
log "WebUI 状态已更新 (共 $TOTAL 个音效)"
log "=== service.sh 完成 ==="
