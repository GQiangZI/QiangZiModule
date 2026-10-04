#!/system/bin/sh
# customize.sh - 安装时执行
SKIPUNZIP=0

# 安装日志
LOGFILE="/storage/emulated/0/Android/Hyper铃声日志/Hyperos_audio_core.log"
mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null
echo "[$(date '+%H:%M:%S')] [install] 模块安装开始 (v8.0 手动挂载版)" >> "$LOGFILE" 2>/dev/null

ui_print ""
ui_print "╔═══════════════════════════════════════╗"
ui_print "║                                       ║"
ui_print "║     🎵 小米音效定制模块 🎵            ║"
ui_print "║                                       ║"
ui_print "║     通知音 · 铃声 · UI 音效           ║"
ui_print "║                                       ║"
ui_print "╚═══════════════════════════════════════╝"
ui_print ""
ui_print "📦 模块名称: 小米音效定制模块"
ui_print "👤 作者: 酷安-強子Loner"
ui_print "📅 版本: v8.0 (手动挂载版)"
ui_print "📱 兼容: HyperOS / MIUI"
ui_print ""
ui_print "挂载方式: post-fs-data 手动 bind mount"
ui_print "音效路径: system/product/media/audio/"
ui_print "  (利用 /system/product → /product 符号链接)"
ui_print ""
ui_print "功能："
ui_print "  - 替换解锁/锁屏/充电音效"
ui_print "  - 加入三星口哨、车锁、苹果三全音"
ui_print "  - 支持 WebUI 控制面板"
ui_print "  - 支持元模块自动同步"
ui_print ""
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "⚙️  正在安装..."
ui_print ""

set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/post-fs-data.sh 0 0 0755
set_perm $MODPATH/service.sh 0 0 0755
set_perm $MODPATH/action.sh 0 0 0755

ui_print ""
ui_print "✅ 安装完成！重启后生效。"
echo "[$(date '+%H:%M:%S')] [install] 模块安装完成" >> "$LOGFILE" 2>/dev/null
