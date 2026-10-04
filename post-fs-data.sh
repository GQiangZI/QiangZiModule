#!/system/bin/sh
# post-fs-data.sh - 手动 bind mount（HyperOS 已验证生效方案）
# 路径利用 /system/product → /product 符号链接，KSU 对 system 分区 overlay 可靠
MODDIR=${0%/*}
LOGFILE="$MODDIR/post-fs-data.log"

log() {
    echo "[$(date '+%H:%M:%S')] [post-fs-data] $*" >> "$LOGFILE"
}

log "=== post-fs-data 启动 ==="

# ── 1. 修复 SELinux 标签（HyperOS audioserver 必须 system_file） ──
if [ -d "$MODDIR/system/product/media/audio" ]; then
    chcon -R u:object_r:system_file:s0 "$MODDIR/system/product/media/audio" 2>/dev/null
    log "chcon: system/product/media/audio → system_file"
fi

# ── 2. 创建目标目录（已存在则跳过） ──
mkdir -p /product/media/audio/notifications /product/media/audio/ringtones /product/media/audio/ui 2>/dev/null
mkdir -p /system/product/media/audio/notifications /system/product/media/audio/ringtones /system/product/media/audio/ui 2>/dev/null

# ── 3. bind mount 函数 ──
bind_dir() {
    local src="$1" dst="$2"
    [ -d "$src" ] || { log "跳过(源不存在): $src"; return 0; }
    local mounted=0 failed=0
    for f in "$src"/*; do
        [ -f "$f" ] || continue
        local fname=$(basename "$f")
        # 目标文件不存在则先创建（/product 只读时可能失败，失败则靠 overlay）
        [ -f "$dst/$fname" ] || touch "$dst/$fname" 2>/dev/null
        if mount -o ro,bind "$f" "$dst/$fname" 2>/dev/null; then
            mounted=$((mounted + 1))
        else
            failed=$((failed + 1))
            log "挂载失败: $dst/$fname"
        fi
    done
    log "目录 $src → $dst: 成功=$mounted 失败=$failed"
}

# ── 4. 挂载到 /product（HyperOS 实际读取路径） ──
bind_dir "$MODDIR/system/product/media/audio/notifications" "/product/media/audio/notifications"
bind_dir "$MODDIR/system/product/media/audio/ringtones" "/product/media/audio/ringtones"
bind_dir "$MODDIR/system/product/media/audio/ui" "/product/media/audio/ui"

# ── 5. 挂载 precast_ringtones.json（铃声选择器元数据） ──
if [ -f "$MODDIR/system/product/media/audio/precast_ringtones.json" ]; then
    [ -f /product/media/audio/precast_ringtones.json ] || touch /product/media/audio/precast_ringtones.json 2>/dev/null
    mount -o ro,bind "$MODDIR/system/product/media/audio/precast_ringtones.json" /product/media/audio/precast_ringtones.json 2>/dev/null \
        && log "已挂载: precast_ringtones.json" || log "挂载失败: precast_ringtones.json"
fi

# ── 6. 动态更新 module.prop 描述 ──
N_STATUS=$(mount | grep -q "/product/media/audio/notifications" && echo "通知✅" || echo "通知❌")
R_STATUS=$(mount | grep -q "/product/media/audio/ringtones" && echo "铃声✅" || echo "铃声❌")
U_STATUS=$(mount | grep -q "/product/media/audio/ui" && echo "UI✅" || echo "UI❌")
sed -i "s/^description=.*/description=[ $N_STATUS $R_STATUS $U_STATUS ] 已就绪.替换解锁、锁屏、充电以及加入三星口哨、车锁提示音、苹果三全音/" "$MODDIR/module.prop" 2>/dev/null

log "挂载状态: $N_STATUS $R_STATUS $U_STATUS"
log "=== post-fs-data 完成 ==="
