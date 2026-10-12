#!/system/bin/sh
# customize.sh - 安装时执行
SKIPUNZIP=0

# ─── 基础校验 ───
[ -z "$MODPATH" ] && abort "! MODPATH 未定义，环境异常"
[ ! -f "$MODPATH/module.prop" ] && abort "! module.prop 缺失，安装中断"

# ─── 安装日志 ───
LOGFILE="$MODPATH/install.log"
log() {
    echo "[$(date '+%m-%d %H:%M:%S')] [install] $*" >> "$LOGFILE" 2>/dev/null
}
START_TIME=$(date +%s)
log "模块安装开始"

# 
ui_print "注意事项~自行内置音效一定要对应系统目录下的文件名"
ui_print "注意事项~自行内置音效一定要对应系统目录下的文件名"
ui_print "注意事项~自行内置音效一定要对应系统目录下的文件名"
ui_print "╔═══════════════════════════════════════╗"
ui_print "║                                       ║"
ui_print "║     🎵 小米音效定制模块 🎵            ║"
ui_print "║                                       ║"
ui_print "║     通知音 · 铃声 · UI 音效           ║"
ui_print "║                                       ║"
ui_print "╚═══════════════════════════════════════╝"
ui_print ""
# 设备信息
MODEL=$(getprop ro.product.marketname 2>/dev/null)
[ -z "$MODEL" ] && MODEL=$(getprop ro.product.model 2>/dev/null)
[ -z "$MODEL" ] && MODEL="未知设备"
ANDROID=$(getprop ro.build.version.release 2>/dev/null)
SDK=$(getprop ro.build.version.sdk 2>/dev/null)

ui_print "┌─ 📱 设备信息 ─────────────────────────"
ui_print "│ 型号 : $MODEL"
ui_print "│ 系统 : Android $ANDROID (SDK $SDK)"
ui_print "│ 内核 : $(uname -r 2>/dev/null)"
ui_print "└───────────────────────────────────────"
ui_print ""

# ═══════════════════════════════════════════
# 模块信息
ui_print "┌─ 📦 模块信息 ─────────────────────────"
ui_print "│ 名称 : 小米音效定制模块"
ui_print "│ 作者 : 酷安-強子Loner"
ui_print "│ 版本 : v2.0"
ui_print "│ 挂载 : post-fs-data 手动 bind mount"
ui_print "│ 源路径 : system/product/media/audio/"
ui_print "│ 目标 : /product/media/audio/"
ui_print "  (利用 /system/product → /product 符号链接)"
ui_print "路径映射system/product/media和product/media"
ui_print "└───────────────────────────────────────"
ui_print ""

# ═══════════════════════════════════════════
# 功能列表
ui_print "┌─ ✨ 功能 ─────────────────────────────"
ui_print "│  ✓ 替换解锁 / 锁屏 / 充电音效"
ui_print "│  ✓ 加入三星口哨 / 车锁 / 苹果三全音"
ui_print "│  ✓ 支持 WebUI 控制面板/面具用户可自行安装WebuiAPKAPP"
ui_print "│  ✓ 支持元模块自动同步"
ui_print "└───────────────────────────────────────"
ui_print ""

ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "⚙️  正在安装..."
ui_print ""

# ═══════════════════════════════════════════
# 安装进度
# ═══════════════════════════════════════════

# ① 升级检查
if [ -d "/data/adb/modules/Hyperos_audio_core" ]; then
    ui_print "  ⟳ 检测到旧版本，执行覆盖更新"
    log "升级安装"
else
    ui_print "  ✚ 全新安装"
fi

# ② 脚本权限
ui_print "  ⚙ 设置脚本权限..."
set_perm_recursive "$MODPATH" 0 0 0755 0644
SCRIPT_OK=0
for f in post-fs-data.sh service.sh action.sh; do
    if [ -f "$MODPATH/$f" ]; then
        set_perm "$MODPATH/$f" 0 0 0755
        SCRIPT_OK=$((SCRIPT_OK + 1))
        log "chmod 0755: $f"
    else
        ui_print "    ⚠ 缺少 $f"
        log "缺少 $f"
    fi
done
ui_print "    ✓ $SCRIPT_OK/3 脚本就绪"

# ③ common 目录
if [ -d "$MODPATH/common" ]; then
    set_perm_recursive "$MODPATH/common" 0 0 0755 0644
    for f in settings.sh settings-cli.sh; do
        [ -f "$MODPATH/common/$f" ] && set_perm "$MODPATH/common/$f" 0 0 0755
    done
    ui_print "  ⚙ 配置模块 common/ 已就位"
    log "common 权限已设置"
else
    ui_print "  ⚠ 未找到 common 目录"
fi

# ④ WebUI 检查
if [ -d "$MODPATH/webroot" ]; then
    ui_print "  ⚙ 配置 WebUI 控制面板"
    ui_print "    ✓ webroot/ 已就位"
else
    ui_print "  ⚠ 未找到 webroot/，WebUI 不可用"
fi

# ⑤ 音效素材统计
ui_print "  ⚙ 音效素材检查"
if [ -d "$MODPATH/system/product/media/audio" ]; then
    A_SRC="$MODPATH/system/product/media/audio"
    N_A=$(ls -1 "$A_SRC/alarms"        2>/dev/null | wc -l | tr -d ' ')
    N_N=$(ls -1 "$A_SRC/notifications" 2>/dev/null | wc -l | tr -d ' ')
    N_R=$(ls -1 "$A_SRC/ringtones"     2>/dev/null | wc -l | tr -d ' ')
    N_U=$(ls -1 "$A_SRC/ui"            2>/dev/null | wc -l | tr -d ' ')
    N_TOTAL=$((N_A + N_N + N_R + N_U))

    [ "$N_A" -gt 0 ] && ui_print "    🔔 闹钟音 : $N_A 个"
    [ "$N_N" -gt 0 ] && ui_print "    📢 通知音 : $N_N 个"
    [ "$N_R" -gt 0 ] && ui_print "    🎵 铃声   : $N_R 个"
    [ "$N_U" -gt 0 ] && ui_print "    🎹 UI 音效 : $N_U 个"

    ui_print "    ──────────────────"
    ui_print "    📊 共 $N_TOTAL 个音效文件"
    log "音效: 闹钟=$N_A 通知=$N_N 铃声=$N_R UI=$N_U 合计=$N_TOTAL"
else
    ui_print "    ⚠ 未找到音效目录 system/product/media/audio/"
    log "!! 音效目录缺失"
fi

# ═══════════════════════════════════════════
# 安装完成
# ═══════════════════════════════════════════
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""
ui_print "  ╔═══════════════════════════════════╗"
ui_print "  ║                                   ║"
ui_print "  ║          ✅ 安 装 完 成 ✅        ║"
ui_print "  ║                                   ║"
ui_print "  ╠═══════════════════════════════════╣"
ui_print "  ║                                   ║"
ui_print "  ║    ╭─────────────────────────╮    ║"
ui_print "  ║    │  ✦ ✦ ✦  強 子  ✦ ✦ ✦   │    ║"
ui_print "  ║    │                         │    ║"
ui_print "  ║    │     ╰ L o n e r ╯       │    ║"
ui_print "  ║    ╰─────────────────────────╯    ║"
ui_print "  ║                                   ║"
ui_print "  ║       重启后音效即可生效          ║"
ui_print "  ║                                   ║"
ui_print "  ╚═══════════════════════════════════╝"
ui_print ""
ui_print "  ⏱ 耗时: ${DURATION}s"
ui_print "  📂 日志: 模块目录/install.log"
ui_print "  💡 提示: 重启后在 KernelSU 里打开 WebUI 可查看状态"
ui_print ""