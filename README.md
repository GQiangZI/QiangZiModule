# 小米音效定制模块（Hyperos_audio_core）

用 bind mount 把 `alarms` / `notifications` / `ringtones` / `ui` 四类音效挂到
`/product/media/audio/` 下，替换系统自带音效。

- 模块 ID：`Hyperos_audio_core`
- 作者：酷安-[強子Loner](https://www.coolapk.com/u/1344888)
- 适用：HyperOS（Android 14+），KernelSU / Magisk / APatch

---

## ⚠️ 必读：锁屏 / 解锁音效不生效怎么办

**症状**：音量正常、铃声正常，只有**锁屏 / 解锁**这两个音效还是原厂的。

**原因**：KernelSU 有一个应用级开关 ——
「超级用户 → 系统界面（`com.android.systemui`）→ **App Profile：自定义** → **卸载模块**」。
它开着的时候，KernelSU 会给系统界面单独建一个挂载命名空间，并把模块挂载
卸掉，于是系统界面读到的仍然是原厂音效文件。这跟模块写得好不好无关。

**解决**：

```
KernelSU → 超级用户 → 点「系统界面」(com.android.systemui)
         → App Profile 选「自定义」
         → 把下面的「卸载模块」开关【关掉】
         → 重启手机
```

方向别搞反：是**关闭**「卸载模块」，不是打开。

> 注意两点：① App Profile 必须是「自定义」，选「默认」时看不到这个开关；
> ② 列表里可能有两个「系统界面」（其中一个带 `USER 999`），选不带标记的那个。

**怎么确认已经好了**：模块列表里看描述

| 描述 | 含义 |
|---|---|
| `[ 闹✅ 铃✅ 通✅ UI✅ ] 已就绪` | 四类都挂上了，正常 |
| `[ 闹✅ 铃✅ 通❌ UI✅ ] 已就绪` | 有 ❌ 的那一类没挂上，看 `post-fs-data.log` |

---

## 安装

1. KernelSU / Magisk 里直接刷入 zip；
2. 重启；
3. 如果锁屏 / 解锁音效没变，按上面「必读」关掉那个开关再重启一次。

升级安装直接覆盖刷入即可，不需要先卸载。

## 卸载

模块管理器里卸载 → 重启。音效文件本身没有被修改过，
重启后系统会自动回落到原厂音效，无需手动恢复。

## 自定义音效

把音效文件按**同名**替换到对应目录：

```
system/product/media/audio/alarms/          闹钟
system/product/media/audio/notifications/   通知
system/product/media/audio/ringtones/       铃声
system/product/media/audio/ui/              UI 音效（Lock / Unlock / charging / disconnect / LowBattery）
```

**文件名必须与系统里已有的完全一致**，大小写也要一致 ——
模块是逐文件 bind mount，名字对不上就等于没放。

想把**新名字**的铃声加进系统铃声列表？模块做不到：设置页读的是 MediaStore
数据库，不是目录。把文件放进 `/sdcard/Ringtones/` 并触发一次扫描：

```sh
content call --uri content://media --method scan_file --arg /sdcard/Ringtones/xxx.ogg
```

## 刷新音效

换完文件后想让系统界面立刻重新读取，有三种方式：

| 方式 | 操作 |
|---|---|
| WebUI | 打开模块 WebUI →「刷新音效」 |
| WebUI（只看） | 「检测状态」，不重启、只报告当前读到几个 |
| 命令行 | `su -c 'sh /data/adb/modules/Hyperos_audio_core/reload.sh'` |

刷新会重启一次系统界面，屏幕闪一下、几秒恢复 —— 所以它**只能由你主动触发**，
模块不会在开机或后台自己去做这件事。

## 常见问题

**Q：换了模块，重启后还是原厂音效？**
A：先看模块描述里有没有 ❌；再确认文件名与系统里的完全一致。

**Q：只有锁屏 / 解锁不生效，别的都生效？**
A：就是上面那个开关。这两个音效由系统界面播放，其它由别的进程播放。

**Q：点模块「操作」按钮发生了什么？**
A：只打开作者酷安主页，不执行任何修复或重启。

**Q：`update.json` 检查更新 404？**
A：仓库根目录需要放 `update.json`，缺失时只影响在线更新检查，不影响使用。

## 工作原理

1. `post-fs-data.sh`：对 `/product`、`/system`、`/system/product` 三个路径基准
   逐文件 `mount -o ro,bind`，把模块里的音效覆盖到系统路径上（支持 `selfmount` 开关）。
2. `service.sh`：开机后统计一次挂载结果，写 `webroot/status.js` 给 WebUI 用，
   并更新模块描述（`闹/铃/通/UI` 四个 ✅/❌）。跑完即退出。
3. `reload.sh`：手动刷新，只在被调用时执行一次，不常驻。
4. `action.sh`：「操作」按钮 = 打开作者主页。

**资源占用**：没有常驻进程、没有定时任务、没有注入。开机两个脚本各跑一次就结束，
之后完全静默。

日志：`/data/adb/modules/Hyperos_audio_core/` 下的
`post-fs-data.log`、`service.log`、`install.log`。

## 版本号

只在 `module.prop` 定义一次：

```
version=v2.1
versionCode=21
```

刷入界面、WebUI、在线更新全部从它读取。发新版改这两行即可，不会再有漏改的地方。

## 仓库结构

```
module.prop              模块元信息（版本号唯一来源）
customize.sh             刷入界面与权限设置
post-fs-data.sh          挂载
service.sh               状态统计 + WebUI 数据 + 描述
reload.sh                手动刷新音效（不常驻）
action.sh                「操作」按钮
uninstall.sh             卸载清理
common/                  settings.sh / settings-cli.sh（selfmount 开关）
webroot/                 WebUI 页面
system/product/media/audio/   音效素材（binary，建议 Git LFS）
CHANGELOG.md             更新日志
update.json              在线更新清单
```

> 音效素材接近 2 MB 全是二进制，建议用 Git LFS 管理，否则仓库每次改音效都会膨胀一整份。

## 已知问题

- 仓库早期根目录的 `system` 是个 1 字节文件而非目录，需删除。
- 未提供 LICENSE。

## 更新日志

见 [CHANGELOG.md](CHANGELOG.md)。