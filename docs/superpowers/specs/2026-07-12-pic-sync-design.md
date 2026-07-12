# PicSync 设计文档

日期：2026-07-12
状态：已与需求方确认

## 1. 项目目标

局域网内多设备图片/视频同步工具，支持 Android 和 Windows。目标是"聚合"而非"镜像"：让用户需要的图片在多台设备上都存在，方便在任意设备上查看使用。

## 2. 已确认的产品决策

| 决策点 | 结论 |
|---|---|
| 技术栈 | Flutter 单代码库，构建 Android + Windows |
| 同步方向 | 单向拉取：用户选择一台源设备，浏览其共享内容，勾选后拉到本机 |
| 触发方式 | 手动点按钮，无后台自动同步 |
| 比较规则 | 仅按文件名（basename，含扩展名）全局比对，不区分大小写；同名即视为已存在，跳过（不比较内容/哈希） |
| 放置规则 | 优先放入本机与"远端文件所在文件夹名"同名的目录；找不到则放入用户指定的默认接收目录 |
| 目录选择 | 可选多个共享目录，递归包含子目录 |
| 文件类型 | 图片 + 视频（扩展名白名单），其他文件忽略 |
| 设备发现 | UDP 广播自动发现为主，手动输入 IP 兜底 |
| 删除语义 | 删除不传播。一边删除后再次同步，文件会被重新拉回（聚合模型的自然结果） |
| 安卓存储权限 | `MANAGE_EXTERNAL_STORAGE`（所有文件访问）。个人自用/直装 APK 场景，不考虑 Play 上架合规 |
| 安全 | 首次连接需对方设备弹窗确认（配对），之后凭 token 免确认；局域网内明文 HTTP，不加密 |

### 明确不做（第一版范围外）

- 自动/后台同步、文件监听
- 删除传播、双向镜像
- 传输加密、互联网穿透
- 断点续传（失败的文件整个重下）
- 内容哈希去重
- iOS / macOS / Linux

## 3. 总体架构

每台设备上的 App 是对等节点，同时具备两个角色：

- **服务端**：App 打开即启动内嵌 HTTP 服务（Dart `shelf`）+ UDP 广播
- **客户端**：浏览其他设备清单、本地比对、HTTP 拉取文件

无数据库。每次同步实时扫描本机共享目录（万级文件秒级完成），配置持久化为单个 JSON 文件。UI 为中文。

## 4. 核心组件

所有组件位于 `lib/services/`，数据模型位于 `lib/models/`，页面位于 `lib/ui/`。

### 4.1 DiscoveryService

- UDP 端口 `45654`（固定），HTTP 端口 `45655`（被占用时向上递增，广播报文中携带实际端口）
- 每 3 秒广播一次 announce 报文（JSON）：`{app: "picsync", ver: 1, deviceId, name, httpPort}`
- 收到他人 announce 时更新设备列表；超过 10 秒未收到则标记离线
- 手动添加的 IP 直接调 `GET /info` 验证并加入列表，持久化保存

### 4.2 HttpServer（shelf）

| 端点 | 说明 |
|---|---|
| `GET /info` | 返回 `{deviceId, name, ver}`，无需配对 |
| `POST /pair` | 请求体 `{deviceId, name}`。触发本机 UI 弹窗；同意后返回 `{token}`，拒绝返回 403。等待用户操作期间请求挂起（超时 60 秒） |
| `GET /manifest` | 返回本机全部共享文件清单（见 4.3）。需要有效 token |
| `GET /file?path=<相对路径标识>` | 返回文件流（`Content-Length` 为文件大小）。需要有效 token；路径仅允许解析到共享目录内，防目录穿越 |

鉴权：请求头 `X-PicSync-Token`。token 为随机 UUID，配对时生成，双方各自持久化（按对方 deviceId 存储）。无效/缺失 token 返回 401，客户端收到 401 时重新走配对流程。

### 4.3 Manifest 格式

```json
{
  "deviceId": "...",
  "name": "小米手机",
  "files": [
    {
      "path": "share0/旅行/day1/IMG_001.jpg",  // 服务端可解析回绝对路径的标识
      "name": "IMG_001.jpg",
      "folder": "day1",                         // 直接父文件夹名，用于放置匹配
      "size": 2048000
    }
  ]
}
```

万级条目的 JSON 约几 MB，一次性传输可接受，第一版不分页。

### 4.4 LibraryScanner

- 递归扫描所有共享目录，按扩展名白名单过滤
- 图片：`jpg jpeg png gif webp bmp heic heif tif tiff`；视频：`mp4 mov mkv avi webm 3gp m4v`
- 产出 `FileEntry{name, size, folder(父文件夹名), absPath}`；直接位于共享目录根下的文件，`folder` 为该共享目录自身的文件夹名（如 `D:/照片/a.jpg` 的 folder 为 `照片`）
- 忽略隐藏文件、`.part` 临时文件

### 4.5 DiffEngine（纯函数）

- 输入：远端 manifest 的文件列表 + 本机扫描结果
- 本机文件名集合：`Set<String>`（basename 小写化）
- 远端文件的 basename（小写）不在集合中 → 缺失
- 输出：缺失文件列表，按远端 `folder` 分组（供选择页展示）

### 4.6 Placer（纯函数 + IO）

对每个待下载文件：

1. 按共享目录列表顺序，在每个共享目录树内查找第一个名为 `file.folder` 的目录（候选包含共享目录本身及其所有子目录；BFS，同层按名称排序）→ 命中即为目标目录
2. 全部未命中 → 默认接收目录
3. 下载写入 `<目标>/<name>.picsync.part`，完成后 rename 为正式文件名
4. rename 前发现目标文件已存在（竞态）→ 删除临时文件，跳过，计为成功

### 4.7 SyncEngine

- 下载队列，并发 3
- 逐文件进度（已收字节/总字节）+ 总进度回调
- 失败（网络错误、尺寸不符、IO 错误）进失败列表；磁盘满则中止整个队列
- 支持对失败列表一键重试

### 4.8 SettingsStore

单个 JSON 文件（应用数据目录）：

```json
{
  "deviceId": "首次启动生成的 UUID",
  "deviceName": "默认取系统主机名/型号，可改",
  "shareDirs": ["D:/照片", "D:/壁纸"],
  "defaultRecvDir": "D:/照片/来自其他设备",
  "pairedDevices": {"<对方deviceId>": {"name": "...", "token": "..."}},
  "manualHosts": ["192.168.1.23"]
}
```

## 5. UI 页面

1. **主页**：在线设备列表（含手动添加 IP 入口）+ 进入"我的共享"设置
2. **共享设置页**：管理共享目录（增删）、设置默认接收目录、修改设备名
3. **选择页**（点击某设备后）：拉清单 + 本地扫描 + 比对；按远端文件夹分组，每组显示"缺 X / 共 Y"，默认勾选全部缺失项，可展开到单文件调整；底部"开始同步"
4. **进度页**：总进度条、当前文件、完成/失败计数；结束后显示摘要，失败项可重试
5. **配对弹窗**（被动方）："设备 XX 请求访问你的图片" 同意/拒绝

首次启动流程（Android）：解释页说明为何需要"所有文件访问"→ 跳转系统授权 → 回来后引导选择共享目录和默认接收目录。

## 6. 一次同步的时序

1. A、B 均打开 App（自动起 HTTP 服务 + UDP 广播）
2. A 主页看到 B 在线，点击 B
3. 未配对 → A 发 `POST /pair`，B 弹窗，同意 → A 获得 token 并保存
4. A 并行执行：`GET /manifest` + 本机扫描 → DiffEngine 比对 → 进入选择页
5. 用户调整勾选，点"开始同步"
6. SyncEngine 逐个 `GET /file`，Placer 决定落盘位置，`.part` → rename
7. 进度页展示，结束出摘要

## 7. 错误处理

| 场景 | 行为 |
|---|---|
| 清单请求超时/失败 | 提示，可重试 |
| 下载中断/断网 | 当前 `.part` 删除；已完成文件保留；失败项进列表可重试 |
| 尺寸校验不符 | 删临时文件，记为失败 |
| 目标文件已存在 | 跳过（不覆盖），计为成功 |
| 磁盘满（IO 异常） | 中止队列，明确提示 |
| token 失效（对方重置） | 客户端收 401 → 重新发起配对 |
| 对方中途离线 | 广播超时标离线；进行中的下载按失败处理 |
| 安卓权限被拒 | 引导页解释 + 跳系统设置；未授权时禁止添加共享目录 |

## 8. 测试策略

- **单元测试**（纯 Dart，无需设备）：
  - DiffEngine：同名跳过、缺失检出、大小写不敏感、跨文件夹同名视为已存在
  - Placer：同名目录命中、多个同名取共享目录顺序第一个、无同名落默认目录
  - 扩展名过滤、隐藏/临时文件忽略
- **协议集成测试**：临时目录夹具 + 本地起 shelf，跑 配对 → manifest → 下载 → 落盘 全链路，断言文件内容与位置
- **手动验收清单**：
  1. Windows ↔ Android 自动发现彼此；关 WiFi 后标离线
  2. 手动 IP 添加成功
  3. 首次连接弹配对，拒绝后无法拉清单，同意后可拉
  4. 缺失文件正确检出；同名文件（含大小写差异）不重复同步
  5. 有同名文件夹时落入同名文件夹；无同名时落入默认目录
  6. 中途断网：无残留 `.part`，重试成功
  7. 视频文件同步成功且可播放；大文件（>500MB）进度正常

## 9. 技术选型

| 用途 | 选择 | 说明 |
|---|---|---|
| HTTP 服务 | `shelf` + `shelf_router` | 成熟、轻量 |
| UDP 发现 | `dart:io` `RawDatagramSocket` | 自写，不引第三方；Android 端申请 MulticastLock |
| HTTP 客户端 | `dart:io` `HttpClient` | 流式下载够用 |
| 目录选择 | Windows: `file_picker`；Android: `filesystem_picker`（基于真实路径，配合所有文件权限） | Android 的 SAF 路径不可用于 `dart:io`，故用真实路径方案 |
| 权限 | `permission_handler` | `MANAGE_EXTERNAL_STORAGE` |
| 状态管理 | `provider` | 规模小，够用 |
| UUID | `uuid` | 设备标识与 token |

## 10. 项目结构

```
lib/
  main.dart
  models/    file_entry.dart, manifest.dart, device.dart, settings.dart
  services/  discovery_service.dart, http_server.dart, http_client.dart,
             library_scanner.dart, diff_engine.dart, placer.dart,
             sync_engine.dart, settings_store.dart
  ui/        home_page.dart, share_settings_page.dart, select_page.dart,
             progress_page.dart, pair_dialog.dart
test/
  unit/      diff_engine_test.dart, placer_test.dart, scanner_test.dart
  integration/ protocol_test.dart
```
