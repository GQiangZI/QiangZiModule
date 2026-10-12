#!/system/bin/sh
# post-fs-data.sh - HyperOS 音效模块挂载
#   - 源路径: $MODDIR/system/product/media/audio
#   - 挂三套: /product、/system、/system/product（逐个去重）
#   - 子目录: alarms notifications ringtones ui
#   - 详细日志
#   - selfmount 开关

MODDIR=${0%/*}
LOGFILE="$MODDIR/post-fs-data.log"

# ═══════════════════════════════════════════
# 日志轮转
# ═══════════════════════════════════════════
if [ -f "$LOGFILE" ] && [ "$(wc -l < "$LOGFILE" 2>/dev/null)" -gt 3000 ]; then
    tail -n 1000 "$LOGFILE" > "$LOGFILE.tmp" 2>/dev/null && mv "$LOGFILE.tmp" "$LOGFILE"
fi

log() {
    echo "[$(date '+%m-%d %H:%M:%S')] [pfd] $*" >> "$LOGFILE"
}

log "════════════════════════════════════════"
log "=== post-fs-data 启动 (v2.0) ==="
log "MODDIR=$MODDIR"
log "Android SDK: $(getprop ro.build.version.sdk)"

# ═══════════════════════════════════════════
# 读取 selfmount 开关
# ═══════════════════════════════════════════
SELFMOUNT=1
if [ -f "$MODDIR/common/settings.sh" ]; then
    . "$MODDIR/common/settings.sh"
    setting_init
    SELFMOUNT=$(setting_get selfmount 1)
    log "settings.sh 已加载, selfmount=$SELFMOUNT"
else
    log "!! settings.sh 不存在, 使用默认 selfmount=1"
fi

# ═══════════════════════════════════════════
# 源目录检查
# ═══════════════════════════════════════════
AUDIO_SRC="$MODDIR/system/product/media/audio"
SUBDIRS="alarms notifications ringtones ui"

log "源目录: $AUDIO_SRC"
if [ ! -d "$AUDIO_SRC" ]; then
    log "!! 源目录不存在, 退出"
    exit 0
fi

for sub in $SUBDIRS; do
    if [ -d "$AUDIO_SRC/$sub" ]; then
        cnt=$(ls -1 "$AUDIO_SRC/$sub" 2>/dev/null | wc -l)
        log "  子目录 $sub: $cnt 个文件"
    else
        log "  子目录 $sub: 不存在"
    fi
done

# ═══════════════════════════════════════════
# 权限修复
# ═══════════════════════════════════════════
log "── 权限修复 ──"
for sub in $SUBDIRS; do
    D="$AUDIO_SRC/$sub"
    [ -d "$D" ] || continue
    chmod 755 "$D" 2>/dev/null
    find "$D" -maxdepth 1 -type f -exec chmod 644 {} \; 2>/dev/null
    chown -R media:media "$D" 2>/dev/null
    log "  权限修复: $sub"
done

if [ -f "$AUDIO_SRC/precast_ringtones.json" ]; then
    chmod 644 "$AUDIO_SRC/precast_ringtones.json" 2>/dev/null
    chown media:media "$AUDIO_SRC/precast_ringtones.json" 2>/dev/null
    log "  权限修复: precast_ringtones.json"
fi

# ═══════════════════════════════════════════
# SELinux 标签
# ═══════════════════════════════════════════
log "── SELinux 标签 ──"
if chcon -R u:object_r:system_file:s0 "$AUDIO_SRC" 2>/dev/null; then
    log "  chcon 成功: system_file"
else
    log "  !! chcon 失败（chcon 可能不可用）"
fi

# ═══════════════════════════════════════════
# selfmount 判断
# ═══════════════════════════════════════════
if [ "$SELFMOUNT" != "1" ]; then
    log "selfmount=0, 跳过自带挂载（交给元模块）"
    tmp="$MODDIR/module.prop.tmp"
    sed "s|^description=.*|description=🎵 由元模块挂载|" \
        "$MODDIR/module.prop" > "$tmp" 2>/dev/null && mv "$tmp" "$MODDIR/module.prop"
    log "=== post-fs-data 完成 ==="
    exit 0
fi

# ═══════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════
is_mounted() {
    grep -q " $1 " /proc/mounts 2>/dev/null
}

same_target() {
    local a="$1" b="$2"
    [ -d "$a" ] && [ -d "$b" ] || return 1
    local ia ib
    ia=$(stat -c %i "$a" 2>/dev/null)
    ib=$(stat -c %i "$b" 2>/dev/null)
    [ -n "$ia" ] && [ "$ia" = "$ib" ]
}

bind_one() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 1

    if is_mounted "$dst"; then
        log "    [跳过] 已挂载: $dst"
        return 0
    fi

    if [ ! -f "$dst" ]; then
        touch "$dst" 2>/dev/null
        if [ ! -f "$dst" ]; then
            log "    [失败] 无法创建目标: $dst（分区只读）"
            return 1
        fi
        log "    [创建] 占位文件: $dst"
    fi

    if mount -o ro,bind "$src" "$dst" 2>/dev/null; then
        log "    [OK-ro] $dst"
        return 0
    fi

    if mount --bind "$src" "$dst" 2>/dev/null; then
        log "    [OK-rw] $dst"
        return 0
    fi

    log "    [失败] $src → $dst"
    return 1
}

MOUNTED_PHYSICAL=""

mount_set() {
    local base="$1"
    local label="$2"

    log "── 检查 $base ($label) ──"

    if [ ! -d "$base/media/audio" ]; then
        log "  跳过: $base/media/audio 不存在"
        MOUNT_OK=0
        MOUNT_FAIL=0
        return
    fi

    local prev
    for prev in $MOUNTED_PHYSICAL; do
        if same_target "$base/media/audio" "$prev"; then
            log "  跳过: $base/media/audio 与 $prev 是同一物理目录"
            MOUNT_OK=0
            MOUNT_FAIL=0
            return
        fi
    done

    MOUNTED_PHYSICAL="$MOUNTED_PHYSICAL $base/media/audio"

    for sub in $SUBDIRS; do
        mkdir -p "$base/media/audio/$sub" 2>/dev/null
    done

    local ok=0 fail=0
    for sub in $SUBDIRS; do
        [ -d "$AUDIO_SRC/$sub" ] || continue
        log "  [$sub]"
        for f in "$AUDIO_SRC/$sub"/*; do
            [ -f "$f" ] || continue
            if bind_one "$f" "$base/media/audio/$sub/${f##*/}"; then
                ok=$((ok + 1))
            else
                fail=$((fail + 1))
            fi
        done
    done

    if [ -f "$AUDIO_SRC/precast_ringtones.json" ]; then
        log "  [precast_ringtones.json]"
        if bind_one "$AUDIO_SRC/precast_ringtones.json" "$base/media/audio/precast_ringtones.json"; then
            ok=$((ok + 1))
        else
            fail=$((fail + 1))
        fi
    fi

    log "  => $base: 成功=$ok 失败=$fail"
    MOUNT_OK=$ok
    MOUNT_FAIL=$fail
}

# ═══════════════════════════════════════════
# 执行挂载
# ═══════════════════════════════════════════
TOTAL_OK=0
TOTAL_FAIL=0

mount_set "/product" "主路径"
TOTAL_OK=$((TOTAL_OK + MOUNT_OK))
TOTAL_FAIL=$((TOTAL_FAIL + MOUNT_FAIL))

mount_set "/system" "旧路径"
TOTAL_OK=$((TOTAL_OK + MOUNT_OK))
TOTAL_FAIL=$((TOTAL_FAIL + MOUNT_FAIL))

mount_set "/system/product" "兼容路径"
TOTAL_OK=$((TOTAL_OK + MOUNT_OK))
TOTAL_FAIL=$((TOTAL_FAIL + MOUNT_FAIL))

# ═══════════════════════════════════════════
# 更新 module.prop
# ═══════════════════════════════════════════
A=$(grep -c " /product/media/audio/alarms/"        /proc/mounts 2>/dev/null)
N=$(grep -c " /product/media/audio/notifications/" /proc/mounts 2>/dev/null)
R=$(grep -c " /product/media/audio/ringtones/"     /proc/mounts 2>/dev/null)
U=$(grep -c " /product/media/audio/ui/"            /proc/mounts 2>/dev/null)

SA=$( [ "$A" -gt 0 ] && echo "✅" || echo "❌" )
SN=$( [ "$N" -gt 0 ] && echo "✅" || echo "❌" )
SR=$( [ "$R" -gt 0 ] && echo "✅" || echo "❌" )
SU=$( [ "$U" -gt 0 ] && echo "✅" || echo "❌" )

NEW_DESC="description=[ 闹${SA} 铃${SR} 通${SN} UI${SU} ] 已就绪"
tmp="$MODDIR/module.prop.tmp"
sed "s|^description=.*|$NEW_DESC|" "$MODDIR/module.prop" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$MODDIR/module.prop" \
    && log "module.prop 已更新: $NEW_DESC"

log "════════════════════════════════════════"
log "挂载汇总: 成功=$TOTAL_OK 失败=$TOTAL_FAIL"
log "分类状态: 闹钟=$SA 铃声=$SR 通知=$SN UI=$SU"
log "=== post-fs-data 完成 ==="
exit 0