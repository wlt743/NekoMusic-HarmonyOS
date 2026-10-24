# NekoMusic HarmonyOS

<img src="docs/images/home.jpeg" alt="NekoMusic HarmonyOS" width="360">

> 为 NekoMusic 准备好你的 HarmonyOS 设备。

NekoMusic 的 HarmonyOS 原生客户端，使用 **ArkTS + ArkUI** 原生构建，对接 NekoMusic 曲库服务。
不带任何音源，曲库、账号、歌单全部由后端提供；客户端专注于播放、管理和沉浸式听歌体验。

> 当前版本：**V7.1**（7.1.0）。首个公开版本，核心功能对齐 iOS 客户端。

## 原生，原生，还是TM的原生

**全部 ArkTS + ArkUI 原生构建，没有 WebView，没有跨端框架。**

- **沉浸光感材质**：顶栏与悬浮播放条使用系统 `uiMaterial.ImmersiveMaterial`，
  随背景自动磨砂；API 26 以下自动退回半透明样式
- **系统符号**：图标全部使用 `SymbolGlyph` 系统符号，跟随系统主题与动效
- **系统能力集成**：媒体会话（AVSession）、折叠形态识别、分屏窗口

## 功能

### 听歌

- 首页推荐 / 最新上架 / 热门排行
- 搜索（歌曲 / 歌手）
- 播放：封面模糊背景、逐行滚动歌词、全屏歌词页（左右滑动切换）
- 底部悬浮播放条：沉浸光感材质、可拖动进度、上一首 / 暂停 / 下一首
- **无歌词时显示歌手名**（Apple Music 风格）

### 收藏与歌单

- 收藏 / 取消收藏（红心状态同步）
- 音乐库：收藏列表 + 我的歌单
- 歌单：创建、查看详情、把歌曲加入歌单

### 账号与内容

- 登录 / 退出，token 持久化
- 头像（NekoMusic 账号头像）、昵称修改
- 评论（列表 / 发表）
- 站内消息（未读数、标记已读）
- **上传音乐**：ID3 元数据自动解析、语言选择、预览播放、上传进度、我的上传列表
- **会员中心**：实时定价、支付宝/微信扫码支付（内置 QRCode 渲染）

### 个性化

- 壁纸（相册选择、模糊处理、持久化）
- 沉浸式状态栏

### 系统能力

- **媒体会话（AVSession）**：歌曲信息、封面、播放状态同步到系统媒体中心 / 锁屏 / 耳机控制；
  为华为多端协同（投播、音频接续）打底
- **实况窗歌词**：`singleLyricText` 随播放滚动，实况窗显示当前歌词行
- **折叠形态适配**：`display.getFoldStatus()` 识别折叠状态，
  合上横屏时播放页切换为紧凑左栏 + 右栏歌词；展开态保持宽屏两栏
- **全方向旋转**：`auto_rotation`，四方向自由旋转
- **分屏 / 悬浮窗**：`supportWindowMode: fullscreen/split/floating`，最小窗口 400×400

## 界面

| 首页 | 播放页 | 音乐库 |
|---|---|---|
| ![](docs/images/home.jpeg) | ![](docs/images/player.jpeg) | ![](docs/images/library.jpeg) |

| 音乐库 | 会员中心 | 播放（宽屏） |
|---|---|---|
| ![](docs/images/library.jpeg) | ![](docs/images/vip.jpeg) | ![](docs/images/player.jpeg) |

## 构建

需要 DevEco Studio 与 HarmonyOS SDK（API 12+，推荐 23+）。

```bash
export PATH=/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
hvigorw assembleHap --mode module -p product=default --no-daemon
```

产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`

## 侧载安装

HAP 不通过应用商店，需要手动「侧载」（sideload）到设备。以下两种方式任选其一。

### 方式一：模拟器（最简单）

DevEco Studio 自带模拟器，不需要签名：

1. DevEco Studio → `Tools` → `Device Manager` → 启动任意模拟器
2. 用 hdc 安装：

```bash
# hdc 在 SDK 的 toolchains 目录下
# macOS: ~/Library/OpenHarmony/Sdk/<版本>/toolchains/hdc
# Windows: %LOCALAPPDATA%\OpenHarmony\Sdk\<版本>\toolchains\hdc

hdc list targets                      # 确认设备已连接
hdc install NekoMusicHarmony-7.1.0-unsigned.hap
hdc shell aa start -a EntryAbility -b com.example.nekomusicharmony
```

### 方式二：真机（需要开发者模式）

**第 1 步：开启开发者模式**

设置 → 关于本机 → 连续点击「版本号」7 次 → 提示「您已处于开发者模式」

**第 2 步：开启 USB 调试**

设置 → 系统 → 开发者选项 → 打开「USB 调试」

**第 3 步：连接电脑**

USB 连接手机，手机弹窗选「传输文件」，并允许调试授权。

**第 4 步：安装**

```bash
hdc list targets                      # 应看到设备序列号
hdc install NekoMusicHarmony-7.1.0-unsigned.hap
```

**第 5 步：签名问题**

未签名 HAP 在真机上安装会失败（`error code 9568289: install failed due to grant request permissions failed`）。
需要签名，两种做法：

- **调试签名**：DevEco Studio 打开本项目 → `File` → `Project Structure` → `Signing Configs` → 勾选
  `Automatically generate signature`（需要登录华为开发者账号）→ 再 `Run`
- **手动签名**：用 DevEco 的 `hvigorw assembleHap` 加签名配置，或用华为的 `hap-sign-tool.jar`

```bash
# 签名后的包直接安装
hdc install entry-default-signed.hap
```

### 常见问题

| 现象 | 原因 | 解决 |
|---|---|---|
| `hdc: command not found` | hdc 不在 PATH | 用 SDK 里的绝对路径，或加入 PATH |
| `no devices found` | 未开 USB 调试 / 未授权 | 重插 USB，手机确认授权弹窗 |
| `install failed due to grant request permissions` | 未签名 | 按上面第 5 步签名 |
| 安装成功但闪退 | 系统版本过低 | 需要 API 12+（HarmonyOS NEXT） |

> 参考：[hdc 官方文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/hdc)、
> [怎么装非应用市场的 App](https://developer.huawei.com/consumer/cn/forum/topic/0209227003236153053)

## 架构

```
entry/src/main/ets/
├── entryability/       EntryAbility（全屏 + 会话初始化）
├── services/
│   ├── APIConfig       接口地址 / 客户端标识
│   ├── PoWWorker       @Concurrent SHA-256 求解
│   ├── HttpClient      GET/POST/DELETE + 重试
│   ├── AuthService     登录态、token 持久化
│   ├── MusicService    曲库、搜索
│   ├── FavoriteService 收藏
│   ├── PlaylistService 歌单
│   ├── AudioPlayerService  播放器
│   ├── PlayerSessionService AVSession 媒体会话
│   ├── CommentService  评论
│   ├── NotificationService 站内消息
│   ├── AudioMetadataParser ID3 解析
│   ├── WallpaperService 壁纸
│   └── MaterialService 沉浸光感
├── components/         RemoteImage / MiniPlayer / 播放按钮等
└── pages/              首页 / 发现 / 音乐库 / 我的 / 播放 / 歌单 / 设置 / 评论 / 消息 / 上传 / 会员
```

## 致谢

- 后端：[FantasyNetworkCN/NekoMusic](https://github.com/FantasyNetworkCN/NekoMusic)
- iOS 客户端：功能对齐参考
