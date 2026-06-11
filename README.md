# RTK for Flutter

![RTK for Flutter](assets/banner.png)

Rena Telemetry Kit is a Flutter SDK for sending application telemetry events and captured errors to Rena server.

The SDK collects only telemetry submitted through its public API. It does not install global error hooks, collect screen names, capture request bodies, or send user input by default.

[中文文档](README.zh-CN.md)

## Features

- Event tracking with `RTK.track`.
- Error capture with `RTK.captureError`.
- Breadcrumbs attached to subsequent error reports.
- Super properties shared across events and errors.
- Batched delivery to `POST /v1/batch`.
- Automatic flush based on `flushAt`, `flushInterval`, and app lifecycle.
- Persistent anonymous ID, session ID, opt-out state, and pending queue.
- Retry with exponential backoff for rate limits, server failures, timeouts, and network errors.
- Client-side enforcement for Rena ingest limits.
- `beforeSend` hook for replacing or dropping telemetry before it is queued.
- Debug logging with public write key redaction.

## Requirements

- Flutter 3.13 or newer.
- Dart SDK compatible with `>=3.1.0 <4.0.0`.
- A running Rena server with a public write key.

## Installation

From GitHub:

```yaml
dependencies:
  rena_rtk:
    git:
      url: https://github.com/Kanscape/RTK-Flutter.git
      ref: v0.1.0
```

## Initialize

```dart
import 'package:rena_rtk/rena_rtk.dart';

await RTK.init(
  RTKConfig(
    endpoint: Uri.parse('https://rena.example.com'),
    publicWriteKey: 'public_xxx',
    environment: 'production',
    appVersion: '1.0.0',
    buildNumber: '100',
  ),
);
```

`publicWriteKey` determines the project scope on Rena server. The SDK does not send `project_id` to `/v1/batch`.

If `platform` and `locale` are not provided, the SDK infers them from the Flutter runtime. `debug` follows Flutter debug mode by default.

## Track Events

```dart
RTK.track(
  'feature_used',
  properties: {
    'feature': 'advanced_search',
    'entry': 'toolbar',
  },
);
```

## Capture Errors

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

Breadcrumbs are attached only to subsequent `captureError` calls. They are not sent as standalone events.

## Flush and Opt Out

```dart
await RTK.flush();
await RTK.setOptOut(true);
```

The SDK starts a flush when the queue reaches `flushAt`, when `flushInterval` elapses, or when app lifecycle changes indicate backgrounding. `flush()` waits for the current delivery attempt. Concurrent flush calls use the same in-flight request.

`setOptOut(true)` blocks new telemetry and clears both memory and persisted queues.

## Before Send

`beforeSend` can replace or drop telemetry before it is queued:

```dart
await RTK.init(
  RTKConfig(
    endpoint: Uri.parse('https://rena.example.com'),
    publicWriteKey: 'public_xxx',
    environment: 'production',
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

## Optional Flutter Error Hooks

Rena Telemetry Kit does not install global error hooks. Applications can enable Flutter-level error capture during initialization:

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

## Privacy Defaults

By default, the SDK does not automatically collect:

- Screen names.
- URLs.
- User input.
- File paths.
- Email addresses.
- User IDs.
- HTTP request bodies.
- Screenshots.

## Rena Ingest Limits

The SDK applies these Rena ingest limits before sending:

- Event name: at most 128 bytes.
- Top-level properties per item: at most 32.
- String property value: at most 1024 characters.
- Batch size: at most 100 items.
- Request body: at most 256 KiB.

The Rena server remains responsible for final authorization, schema validation, privacy sanitization, and rate limiting.

## Development

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
dart pub publish --dry-run
```

## License

Apache-2.0. See [LICENSE](LICENSE).
