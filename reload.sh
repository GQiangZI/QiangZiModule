#!/system/bin/sh
# ═══════════════════════════════════════════════════════════════
# reload.sh —— 手动刷新系统界面音效
#
# 不常驻、不定时、不后台，只在被调用的这一刻执行一次。
#
#   sh reload.sh          重启 SystemUI，让它重新读取音效文件
#   sh reload.sh check    只检测，不重启
#
# 什么时候用：
#   · 刚换掉模块里的 ogg，想立刻听到新音效
#   · 刚关掉 KernelSU → 超级用户 → 系统界面 →「卸载模块」，想立刻生效
# 平时开机不需要跑它。
# ═══════════════════════════════════════════════════════════════

MODDIR=${0%/*}
[ -d "$MODDIR" ] || MODDIR=/data/adb/modules/Hyperos_audio_core

AUDIO_SRC="$MODDIR/system/product/media/audio"
FILES="Lock.ogg Unlock.ogg charging.ogg disconnect.ogg LowBattery.ogg"
MODE="${1:-restart}"

get_pid() {
    if command -v pidof >/dev/null 2>&1; then
        pidof com.android.systemui 2>/dev/null | awk '{print $1; exit}'
        return
    fi
    ps -A 2>/dev/null | grep -F 'com.android.systemui' | grep -v grep \
        | head -n1 | awk '{print $2}'
}

same_file() {
    local a b
    a=$(stat -c %i "$1" 2>/dev/null)
    b=$(stat -c %i "$2" 2>/dev/null)
    [ -n "$a" ] && [ -n "$b" ] && [ "$a" = "$b" ]
}

global_count() {
    local f n=0
    for f in $FILES; do
        same_file "/product/media/audio/ui/$f" "$AUDIO_SRC/ui/$f" && n=$((n + 1))
    done
    echo "$n"
}

visible_count() {
    local pid="$1" f n=0
    [ -n "$pid" ] || { echo 0; return; }
    for f in $FILES; do
        same_file "/proc/$pid/root/product/media/audio/ui/$f" "$AUDIO_SRC/ui/$f" && n=$((n + 1))
    done
    echo "$n"
}

restart_sysui() {
    local old new i=0
    old=$(get_pid)
    if [ -z "$old" ]; then
        echo "✗ 没有找到 SystemUI 进程"
        return 1
    fi
    kill "$old" 2>/dev/null
    while [ "$i" -lt 60 ]; do
        sleep 0.5 2>/dev/null || sleep 1
        new=$(get_pid)
        if [ -n "$new" ] && [ "$new" != "$old" ]; then
            sleep 2
            echo "$new"
            return 0
        fi
        i=$((i + 1))
    done
    echo "✗ 等待 SystemUI 重启超时（30s）"
    return 1
}

pid=$(get_pid)
global_n=$(global_count)
before=$(visible_count "$pid")
echo "SystemUI pid=${pid:-无} · 全局挂载 ${global_n}/5 · 系统界面可读 ${before}/5"

if [ "$MODE" = "check" ]; then
    if [ "$before" -eq 5 ]; then
        echo "✅ 系统界面读到的就是模块音效，正常"
    elif [ "$global_n" -eq 0 ]; then
        echo "⚠️ 全局路径上也是原厂音效 —— 模块没挂上"
        echo "   先确认模块已在管理器里启用，然后重启手机"
    elif [ "$global_n" -ge 4 ]; then
        echo "⚠️ 全局已挂载，但系统界面读到的是原厂音效"
        echo "   九成是 KernelSU → 超级用户 → 系统界面 → App Profile 自定义 →「卸载模块」还开着"
        echo "   关掉它再重启；想立刻试也可以执行：sh reload.sh"
    else
        echo "⚠️ 全局只挂上 ${global_n}/5，去看 post-fs-data.log"
    fi
    exit 0
fi

if [ "$before" -eq 5 ]; then
    echo "✅ 已经读到模块音效，无需重启"
    exit 0
fi

if [ "$global_n" -eq 0 ]; then
    echo "✗ 全局路径上都不是模块文件，重启界面没有意义"
    echo "   先确认模块已启用，然后重启手机"
    exit 1
fi

echo "▶ 正在重启 SystemUI…"
if new=$(restart_sysui); then
    :
else
    echo "$new"
    exit 1
fi
after=$(visible_count "$new")
echo "▶ 重启完成 · 新 pid=$new · 系统界面可读 ${after}/5"

if [ "$after" -eq 5 ]; then
    echo "✅ 已生效，锁屏/解锁音效应该变了"
elif [ "$global_n" -ge 4 ]; then
    echo "⚠️ 仍是 ${after}/5：系统界面有自己的挂载空间"
    echo "   请关闭 KernelSU → 超级用户 → 系统界面 → App Profile 自定义 →「卸载模块」，再重启手机"
else
    echo "⚠️ 全局挂载本身只有 ${global_n}/5，先修挂载再看这里"
fi
exit 0
