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
ui_print "╔═══════════════════════════════════════╗"
ui_print "║                                       ║"
ui_print "║          ⚠️  刷 入 前 必 读  ⚠️        ║"
ui_print "║                                       ║"
ui_print "╠═══════════════════════════════════════╣"
ui_print "║ 如果你的手机是「锁屏 / 解锁音效不生效」 ║"
ui_print "║ （音量、铃声都正常，只有这两个不响）， ║"
ui_print "║ 请装好后做这一件事：                   ║"
ui_print "║                                       ║"
ui_print "║  KernelSU → 超级用户 → 系统界面        ║"
ui_print "║  (com.android.systemui)                ║"
ui_print "║  → App Profile 选【自定义】            ║"
ui_print "║  →「卸载模块」开关保持【关闭】         ║"
ui_print "║  → 重启手机                            ║"
ui_print "║                                       ║"
ui_print "║ 原因：这个开关开着时，KernelSU 会给    ║"
ui_print "║ 系统界面单独建一个挂载空间，把模块挂载 ║"
ui_print "║ 卸掉，系统界面读到的还是原厂音效。      ║"
ui_print "║                                       ║"
ui_print "║ 注意方向：是【关闭】「卸载模块」，      ║"
ui_print "║ 不是打开。关掉后系统界面就能正常读到    ║"
ui_print "║ 模块音效，与正常机型行为一致。          ║"
ui_print "╚═══════════════════════════════════════╝"
ui_print ""
ui_print "╔═══════════════════════════════════════╗"
ui_print "║                                       ║"
ui_print "║     🎵 小米音效定制模块 🎵            ║"
ui_print "║                                       ║"
ui_print "║     通知音 · 铃声 · UI 音效           ║"
ui_print "║                                       ║"
ui_print "╚═══════════════════════════════════════╝"
ui_print ""
ui_print "注意事项：自行添加音效时，文件名必须与系统目录下已有的文件名一致"
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
VER=$(grep -m1 '^version=' "$MODPATH/module.prop" 2>/dev/null | cut -d= -f2-)
ui_print "│ 版本 : ${VER:-未知}"
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
ui_print "│  ✓ 无常驻进程 · 开机挂载一次即止"
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
SCRIPT_ALL=0
for f in "$MODPATH"/*.sh; do
    [ -f "$f" ] || continue
    SCRIPT_ALL=$((SCRIPT_ALL + 1))
    if set_perm "$f" 0 0 0755; then
        SCRIPT_OK=$((SCRIPT_OK + 1))
        log "chmod 0755: ${f##*/}"
    else
        log "chmod 失败: ${f##*/}"
    fi
done
for f in post-fs-data.sh service.sh; do
    [ -f "$MODPATH/$f" ] || { ui_print "    ⚠ 缺少关键脚本 $f"; log "!! 缺少 $f"; }
done
ui_print "    ✓ $SCRIPT_OK/$SCRIPT_ALL 个脚本已设为 0755"

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
ui_print "  💡 提示: 重启后打开 WebUI 可看状态、手动刷新音效"
ui_print "          模块无常驻进程，不会自动重启界面"
ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print " ❗ 锁屏 / 解锁音效不响？九成是这一个开关："
ui_print ""
ui_print "    KernelSU → 超级用户 → 系统界面"
ui_print "    (com.android.systemui)"
ui_print "    → App Profile 选【自定义】"
ui_print "    → 「卸载模块」保持【关闭】 → 重启手机"
ui_print ""
ui_print "    重启后看模块列表里的描述："
ui_print "    [ 闹✅ 铃✅ 通✅ UI✅ ] 已就绪 = 四类都挂上了"
ui_print "    出现 ❌ 就是那一类没挂上。"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print ""