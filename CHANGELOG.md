更新日志：v2.0
🎉 新增
· WebUI 新增「自带挂载」开关：可切换由模块自挂或交给元模块处理，重启生效
· 新增元模块自动检测：识别 Magic Mount / hybrid_mount / meta-overlayfs / mountify / KernelSU MetaModule
· 设备信息支持汉字型号：显示如 REDMI K90 Pro Max
· 安装界面全面美化：带框线、设备信息、音效统计、署名

🐛 修复
· 修复锁屏 / 解锁音效无法替换的问题
· 根因：/system/product 是符号链接，直接挂 /system/media 时 KSU 不跟随软链，导致 SystemUI 读不到替换文件
· 方案：源路径改为 system/product/media/audio/，同时手动 bind mount 到 /product/
· 修复 FadeIn.ogg 拼写错误（原为 Fadeln.ogg，小写 L）
· 修复 /product 只读分区无法新增文件的挂载失败：仅对系统已有文件生效，新文件需改为系统已有文件名
· 修复日志无限增长问题：超过 3000 行自动保留最近 1000 行
· 修复 module.prop 直接 sed -i 写入的原子性问题：改为临时文件
· 修复型号显示英文（原来只取 ro.product.model）

⚙️ 优化
· 日志全部移至模块目录，不再写入 /sdcard/Android/（避免权限和路径问题）
· 日志分级：主流程用 log，逐文件细节用 vlog（verbose 控制）
· 挂载物理去重：/product、/system、/system/product 三套路径自动检测同一 inode，避免重复挂载
· 挂载幂等：已挂载的文件自动跳过
· ro,bind 失败时回退到 rw bind，兼容部分内核
· 元模块副本先清后拷，避免删除文件后残留
· 音效分类计数：无源文件的分类自动跳过索引，避免白扫原生闹钟
· content insert 补类型标志（is_notification / is_ringtone / is_alarm），确保新音频在铃声选择器中可见
· SELinux 标签统一为 u:object_r:system_file:s0
· WebUI 全面重构：
  · 外链 URL 白名单 + shell 转义，避免命令注入
  · applyStatus 全面防御，字段缺失不崩溃
  · fetch 失败可见，走兜底提示
  · CSS 抽离 card--dark 基类，减少重复
  · 可访问性：input 用 sr-only 隐藏，支持键盘焦点

🗑️ 移除
· 移除 WebUI 上的三个旧开关（开机自动刷新、清除铃声缓存、详细日志）
· 对应功能改为默认开启，不再需要用户手动切换
· 仅保留「自带挂载」一个开关
· 移除 /storage/emulated/0/Android/Hyper铃声日志/ 日志路径（改为模块目录）
· 移除元模块强制同步逻辑（改由「自带挂载」开关控制）
· 移除对 system/media/audio/ 路径的依赖（避免与 /system/product 软链混淆）

⚠️ 已知限制

· 仅支持 HyperOS 3/4 · Android 15-17，不支持 Android 9 及以下（无 /product 分区）
· 内核要求 6.6+
· 新增文件到只读分区受限于系统已有文件名：只读分区（EROFS）无法创建新文件，新增音频须改名为系统已有文件名才能生效

---

📦 安装说明

1. KernelSU 中刷入模块
2. 重启
3. 打开 WebUI 查看挂载状态
4. 锁屏 / 解锁 / 充电 / 拔电 / 通知音 / 铃声
调试不易，且用且珍惜 🎵
