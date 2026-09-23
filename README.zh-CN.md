# pi-web 自定义主题 — greenscreen

中文说明 | [English](README.md)

给 [pi-web](https://github.com/agegr/pi-web) 换上一套终端 / CRT 皮肤：全等宽字体、方角、扫描线、荧光绿。**一条命令启用，一条命令还原，而且能在 `npm install -g` 升级后自动存活。**

![greenscreen 应用在 pi-web 上](docs/greenscreen-home.png)

## 特点

- **全局等宽字体**——JetBrainsMono Nerd Font（带完整回退链），界面和内嵌终端面板一起换
- **方角 + CRT 扫描线 + 荧光绿配色**
- pi-web 内置的 5 个主题（Light / Dark / Mist / Rose / Pine）被映射成 5 套终端配色，所以自带主题切换器照常可用，包括「跟随系统」

| pi-web 主题 | 变成 | 底色 | 前景 |
|---|---|---|---|
| Light | Phosphor Green | `#08120e` | `#7cffb2` |
| **Dark** | **Matrix** | `#020403` | `#00ff41` |
| Mist | Cyberdeck Cyan | `#001014` | `#7ef9ff` |
| Rose | Neon Magenta | `#120016` | `#ff9dff` |
| Pine | Amber CRT | `#140d00` | `#ffb000` |

![主题切换面板](docs/greenscreen-settings.png)

## 为什么可以放心试

| | |
|---|---|
| **不改原文件** | 不重写 pi-web 的任何文件，只是往编译好的 CSS 末尾追加一段带标记的覆盖块（`/* === pi-web-hacker-theme:BEGIN === */ … END */`） |
| **逐字节还原** | 第一次改动前会备份原始文件并记录 sha256；`use.sh off` 恢复后重新校验哈希 |
| **不阻塞启动** | 可选的启动包装器每次启动自动重打皮肤；万一打补丁失败，pi-web 照常启动，只是没皮肤 |
| **升级免维护** | `npm install -g @agegr/pi-web@latest` 之后，包装器会发现新的文件、归档过期备份、重建并重新打皮肤，你什么都不用记 |

## 环境要求

- 已安装 [pi-web](https://github.com/agegr/pi-web)（`npm install -g @agegr/pi-web@latest`）
- macOS 或 Linux，`bash`、`python3`（macOS 自带）
- 可选：[JetBrainsMono Nerd Font](https://www.nerdfonts.com/)——不装会回退到 pi-web 自带的 Noto Sans Mono

## 快速开始

```bash
git clone https://github.com/adamcjm/pi-web-custom-theme.git ~/.pi/custom-theme
cd ~/.pi/custom-theme
./install.sh
```

`install.sh` 会：

1. 自动定位你的 pi-web 安装位置（npm 全局目录、npx 缓存，或 `PATH` 里的 `pi-web`）
2. 把皮肤写进去，并把选择记录到 `active`
3. 把本仓库的 `bin/` 加到 shell rc 的 `PATH` 最前面，这样升级后会自动重打皮肤

然后浏览器**硬刷新**：macOS 是 `Cmd+Shift+R`，Windows/Linux 是 `Ctrl+Shift+R`。

> clone 到别的位置也可以——所有脚本都以自身位置定位，没有任何路径写死成 `~/.pi/custom-theme`。

## 使用

```bash
./use.sh                 # 列出皮肤和用法
./use.sh status          # 开关状态、文件是否已打补丁、备份记录
./use.sh greenscreen     # 启用（并记住）某个皮肤
./use.sh off             # 还原成官方原版，sha256 校验
```

启用或切换皮肤**不需要重启 pi-web**——Next.js 每次请求都从磁盘读那个 CSS。

需要时可以覆盖环境变量：

| 变量 | 用途 |
|---|---|
| `PI_WEB_PKG` | 自动探测失败时，手动指定 pi-web 包目录 |
| `PI_WEB_REAL` | 让启动包装器指向真正的 `bin/pi-web.js` |

## 升级 pi-web

```bash
npm install -g @agegr/pi-web@latest
pi-web
```

就这样。只要包装器在 `PATH` 里，皮肤会自动重打、备份会为新版本重建。（如果你用 `--no-launcher` 安装的，升级后跑一次 `./use.sh greenscreen` 即可。）

## 卸载

```bash
./use.sh off                  # 先还原，带校验
# 再删掉 shell rc 里本仓库加的那行 PATH
rm -rf ~/.pi/custom-theme
```

## 自己做一套皮肤

皮肤就是一个带标记块的 CSS 文件：

```bash
cp -r greenscreen amber
$EDITOR amber/skin.css        # 改 --bg / --text / --accent
./use.sh amber
```

配色都在文件底部的 `[data-theme="…"]` 块里，它们对应 pi-web 自己的主题切换器。

## 原理

三个机制，完全不碰 pi-web 的源码：

**1. 注入 CSS 变量。** pi-web 的外观全部由一个编译后的 CSS 文件驱动（Tailwind + 一组 `[data-theme]` 自定义属性）。皮肤在文件末尾追加一个带标记的覆盖块：

```css
/* === pi-web-hacker-theme:BEGIN === */
… 皮肤内容 …
/* === pi-web-hacker-theme:END === */
```

`restore.sh` 要么把这段剪掉，要么用记录的备份覆盖，然后校验 sha256。

**2. 补丁 Service Worker。** pi-web 是 PWA，它的 Service Worker 对 `/_next/static/` 用 **cache-first**，而服务器给这些文件的是 `immutable`（一年）。不处理的话，改过的 CSS 永远到不了已经访问过的浏览器。所以 `apply.sh` 会同时改 `public/sw.js`：

| 改动 | 作用 |
|---|---|
| 缓存名加上皮肤指纹（`-hc510d86a`） | 新 SW 激活时丢弃旧的静态缓存 |
| 缓存未命中时用 `fetch(request, { cache: "reload" })` | 绕过 `immutable` 的 HTTP 强缓存 |

换皮肤 → 指纹变化 → 所有设备（手机也一样）刷新即更新。

**3. 启动包装器。** `bin/pi-web` 排在 npm 的 shim 前面。每次启动时它先幂等地重打一次皮肤，再把控制权交给真正的启动器。因为它住在 npm 目录之外，`npm install -g` 覆盖不到它——这就是皮肤能扛住升级的原因。

## 目录结构

```
.
├── install.sh          一键安装
├── use.sh              切换 / 状态 / 关闭
├── apply.sh            写入皮肤（备份自愈）
├── restore.sh          逐字节还原，sha256 校验
├── lib.sh              共用函数（定位 pi-web）
├── bin/pi-web          启动包装器（PATH 前置）
├── active              当前皮肤名（运行时状态）
├── backup/             原始文件 + manifest.json
├── greenscreen/        皮肤本体
│   ├── skin.css
│   └── README.md
└── docs/               截图
```

## 许可

MIT — 见 [LICENSE](LICENSE)。

本仓库不包含任何 pi-web 代码，只在运行时给本机已安装的那份打补丁。
