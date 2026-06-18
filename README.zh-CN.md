# RTK for Flutter

![RTK for Flutter](assets/banner.png)

Rena Telemetry Kit 是一个 Flutter SDK，用于将应用 telemetry 事件和捕获到的错误发送到 Rena server。

SDK 只采集通过公开 API 提交的 telemetry。默认不会安装全局错误 hook，不会采集页面名称、请求体或用户输入。

[English](README.md)

## 功能

- `RTK.track` 事件采集。
- `RTK.captureError` 错误上报。
- 附加到后续错误报告的 breadcrumbs。
- 事件和错误共享的 super properties。
- 批量发送到 `POST /v1/batch`。
- 达到 `flushAt`、超过 `flushInterval`、或 app lifecycle 变化时自动发送。
- 通过本地 checkpoint 自动记录 app 前台停留时间。
- 可用时自动附加 platform、locale、OS version 和 device model context。
- 匿名 ID、opt-out 状态和待发送队列持久化。
- 对 rate limit、服务端错误、timeout、网络错误做指数退避重试。
- 客户端发送前应用 Rena ingest 限制。
- `beforeSend` 可在入队前替换或丢弃 telemetry。
- debug 日志会对 public write key 做脱敏处理。

## 要求

- Flutter 3.13 或更新版本。
- Dart SDK 兼容 `>=3.1.0 <4.0.0`。
- 可访问的 Rena server。
- Rena public write key。

## 安装

从 GitHub 安装：

```yaml
dependencies:
  rena_rtk:
    git:
      url: https://github.com/Kanscape/RTK-Flutter.git
      ref: v0.3.0
```

## 初始化

```dart
import 'package:rena_rtk/rena_rtk.dart';

await RTK.init(
  RTKConfig(
    endpoint: Uri.parse(const String.fromEnvironment('RENA_ENDPOINT')),
    publicWriteKey: const String.fromEnvironment('RENA_PUBLIC_WRITE_KEY'),
    appVersion: '1.0.0',
    buildNumber: '100',
  ),
);
```

`endpoint` 和 `publicWriteKey` 应来自 app 自己的配置，例如 `--dart-define` 或 release config 文件。SDK 不内置 Rena host。

`publicWriteKey` 是在 `rena-api` 容器内通过 Rena Admin CLI 创建的 project public write key。key 会决定目标 project，SDK 不向 `/v1/batch` 发送 `project_id`。

Rena project 创建时应使用 `sdk_family=flutter`。SDK 通过 telemetry context 上报运行环境 platform，比如 `android`、`iOS`、`macOS` 或 `web`；它不是 project-level 字段。

`runtimePlatform` 和 `locale` 未传时，由 Flutter 运行环境推断。`osName`、`osVersion`、`deviceModel` 未传时，SDK 会尝试通过 `device_info_plus` 推断；拿不到的字段不会发送，手动传入的值优先。`debug` 默认跟随 Flutter debug mode。

## 事件

```dart
RTK.track(
  'feature_used',
  properties: {
    'feature': 'advanced_search',
    'entry': 'toolbar',
  },
);
```

## 错误

```dart
try {
  await sync();
} catch (error, stackTrace) {
  RTK.captureError(
    error,
    stackTrace: stackTrace,
    properties: {'module': 'sync'},
  );
}
```

## Breadcrumbs

```dart
RTK.addBreadcrumb(
  'sync_started',
  properties: {'source': 'manual'},
);
```

Breadcrumbs 仅附加到后续 `captureError` 调用，不会作为独立 event 发送。

## 前台停留时间

SDK 默认记录 app 前台停留时间。当前前台段只写入本地，下一次 app 启动或回到前台时，SDK 会发送上一次前台段。

发送的 event name 是 `app_foreground_session`：

```json
{
  "duration_ms": 120000,
  "started_at": "2026-06-10T12:00:00Z",
  "ended_at": "2026-06-10T12:02:00Z",
  "recovered": true
}
```

SDK 默认每 15 秒更新一次本地 checkpoint。如果 app 在下一次 checkpoint 前被系统结束，本次前台时间最多会少记一个 checkpoint 间隔。

配置项：

```dart
RTKConfig(
  endpoint: Uri.parse(const String.fromEnvironment('RENA_ENDPOINT')),
  publicWriteKey: const String.fromEnvironment('RENA_PUBLIC_WRITE_KEY'),
  trackForegroundDuration: true,
  foregroundDurationCheckpointInterval: const Duration(seconds: 15),
)
```

## Flush 和 Opt-Out

```dart
await RTK.flush();
await RTK.setOptOut(true);
```

SDK 会在队列达到 `flushAt`、超过 `flushInterval`、或 app lifecycle 表示进入后台时启动发送。`flush()` 会等待当前发送完成；并发调用会复用同一个发送请求。

`setOptOut(true)` 会阻止新增 telemetry，并清空内存队列和本地持久化队列。

## Before Send

`beforeSend` 可以在 telemetry 入队前替换或丢弃 item：

```dart
await RTK.init(
  RTKConfig(
    endpoint: Uri.parse(const String.fromEnvironment('RENA_ENDPOINT')),
    publicWriteKey: const String.fromEnvironment('RENA_PUBLIC_WRITE_KEY'),
    beforeSend: (item) {
      final json = item.toJson();
      if (json['name'] == 'debug_only') {
        return null;
      }
      return item;
    },
  ),
);
```

## 可选 Flutter 错误 Hook

SDK 不会默认安装全局错误 hook。应用可以在初始化阶段启用 Flutter 级错误捕获：

```dart
FlutterError.onError = (details) {
  FlutterError.presentError(details);
  RTK.captureError(details.exception, stackTrace: details.stack);
};

PlatformDispatcher.instance.onError = (error, stack) {
  RTK.captureError(error, stackTrace: stack);
  return false;
};
```

## 隐私默认值

SDK 默认不自动采集：

- 页面名称。
- URL。
- 用户输入。
- 文件路径。
- 邮箱。
- 用户 ID。
- HTTP request body。
- 截图。

SDK 会在可用时自动发送 runtime platform、locale、OS name、OS version 和 device model context。

前台停留时间只发送时间字段，并沿用 batch 已有的 SDK anonymous ID。它不会采集页面名称或用户输入。

## Rena Ingest 限制

SDK 发送前会应用以下 Rena ingest 限制：

- event name 最长 128 bytes。
- 每个 item 最多 32 个顶层 properties。
- property string value 最长 1024 字符。
- batch 最多 100 个 items。
- batch 请求体最大 256 KiB。

服务端负责最终鉴权、schema 校验、敏感字段清洗和 rate limit。

## 开发

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
dart pub publish --dry-run
```

## License

Apache-2.0。参见 [LICENSE](LICENSE)。
