#!/system/bin/sh
# 模块「操作」按钮：打开作者酷安主页
#
# 这里刻意不做任何修复 / 重启动作 —— 点一下按钮就把界面重启一遍太打扰。
# 需要刷新音效时：打开 WebUI 点「刷新音效」，或手动执行 reload.sh

am start --user 0 -a android.intent.action.VIEW -d "https://www.coolapk.com/u/1344888" >/dev/null 2>&1 \
    || am start -a android.intent.action.VIEW -d "https://www.coolapk.com/u/1344888" >/dev/null 2>&1
exit 0
