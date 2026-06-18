import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';

import 'rtk_batch.dart';
import 'rtk_breadcrumb.dart';
import 'rtk_clock.dart';
import 'rtk_config.dart';
import 'rtk_context.dart';
import 'rtk_device_info.dart';
import 'rtk_error.dart';
import 'rtk_event.dart';
import 'rtk_ids.dart';
import 'rtk_json.dart';
import 'rtk_lifecycle.dart';
import 'rtk_logger.dart';
import 'rtk_queue.dart';
import 'rtk_retry.dart';
import 'rtk_storage.dart';
import 'rtk_transport.dart';

class RenaRTK {
  RenaRTK({
    required this.config,
    RTKQueue? queue,
    this.clock = const RTKClock(),
    RTKIdGenerator? idGenerator,
    http.Client? httpClient,
    RTKDeviceInfoProvider? deviceInfoProvider,
  })  : _queue = queue ?? RTKQueue(maxQueueSize: config.maxQueueSize),
        _idGenerator = idGenerator ?? RTKIdGenerator(),
        _transport = RTKHttpTransport(config: config, client: httpClient),
        _retryPolicy = RTKRetryPolicy(
          maxAttempts: config.maxRetryAttempts,
          minDelay: config.minRetryDelay,
          maxDelay: config.maxRetryDelay,
        ),
        _logger = RTKLogger(enabled: config.debug),
        _deviceInfoProvider =
            deviceInfoProvider ?? RTKDefaultDeviceInfoProvider();

  final RTKConfig config;
  final RTKClock clock;
  final RTKQueue _queue;
  final RTKIdGenerator _idGenerator;
  final RTKHttpTransport _transport;
  final RTKRetryPolicy _retryPolicy;
  final RTKLogger _logger;
  final RTKDeviceInfoProvider _deviceInfoProvider;
  final Map<String, Object?> _superProperties = {};
  final List<RTKBreadcrumb> _breadcrumbs = [];

  bool _isStarted = false;
  bool _isOptedOut = false;
  String? _anonymousId;
  RTKResolvedDeviceInfo _deviceInfo = const RTKResolvedDeviceInfo();
  RTKStorage? _storage;
  RTKLifecycleBinding? _lifecycleBinding;
  Timer? _flushTimer;
  Timer? _foregroundSessionTimer;
  Future<void> _pendingPersist = Future<void>.value();
  Future<void>? _activeFlush;
  bool _foregroundSessionActive = false;

  bool get isStarted => _isStarted;

  bool get isOptedOut => _isOptedOut;

  int get pendingCount => _queue.length;

  Future<void> start() async {
    if (_isStarted) {
      return;
    }
    WidgetsFlutterBinding.ensureInitialized();
    _storage = await RTKStorage.create(idGenerator: _idGenerator);
    _isOptedOut = await _storage!.isOptedOut();
    _anonymousId = await _storage!.anonymousId();
    _deviceInfo = await _resolveDeviceInfo();
    if (!_isOptedOut) {
      final pendingBeforeStart = _queue.items;
      _queue.restore([...await _storage!.loadQueue(), ...pendingBeforeStart]);
    } else {
      _queue.clear();
    }
    _isStarted = true;
    _logger.initialized(
      endpoint: config.endpoint,
      publicWriteKey: config.publicWriteKey,
    );
    await _enterForeground();
    await _persistQueue();
    _startFlushTimer();
    _lifecycleBinding ??= RTKLifecycleBinding(
      RTKLifecycleController(
        onFlush: flush,
        onResume: _enterForeground,
        onBackground: _leaveForeground,
      ),
    );
    if (config.enabled && !_isOptedOut) {
      _enqueue(
        RTKEvent(
          name: 'app_launch',
          timestamp: clock.now(),
          properties: _prepareProperties(null),
        ),
      );
    }
    if (_queue.length >= config.flushAt) {
      _scheduleFlush('flushAt');
    }
  }

  void track(String name, {Map<String, Object?>? properties}) {
    if (!config.enabled || _isOptedOut) {
      return;
    }
    _enqueue(
      RTKEvent(
        name: name,
        timestamp: clock.now(),
        properties: _prepareProperties(properties),
      ),
    );
  }

  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) {
    if (!config.enabled || _isOptedOut) {
      return;
    }
    _enqueue(
      RTKError(
        errorType: error.runtimeType.toString(),
        message: error.toString(),
        stack: stackTrace?.toString(),
        timestamp: clock.now(),
        properties: _prepareProperties(properties),
        breadcrumbs: List<RTKBreadcrumb>.of(_breadcrumbs),
      ),
    );
  }

  void addBreadcrumb(String name, {Map<String, Object?>? properties}) {
    if (!config.enabled || _isOptedOut) {
      return;
    }
    _breadcrumbs.add(
      RTKBreadcrumb(
        name: name,
        timestamp: clock.now(),
        properties: rtkNormalizeProperties(
          properties,
          onDroppedProperty: (path, reason) =>
              _logger.propertyDropped(path: path, reason: reason),
        ),
      ),
    );
    while (_breadcrumbs.length > config.maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  void setSuperProperties(Map<String, Object?> properties) {
    _superProperties
      ..clear()
      ..addAll(properties);
  }

  void _enqueue(RTKBatchItem item) {
    final beforeSend = config.beforeSend;
    final prepared = beforeSend == null ? item : beforeSend(item);
    if (prepared == null) {
      _logger.dropped(reason: 'before_send');
      return;
    }
    final droppedBefore = _queue.droppedCount;
    _queue.enqueue(prepared);
    if (_queue.droppedCount > droppedBefore) {
      _logger.dropped(reason: 'queue_limit');
    }
    _logger.enqueued(pendingCount: _queue.length);
    _afterEnqueue();
  }

  Map<String, Object?> _prepareProperties(Map<String, Object?>? properties) {
    return rtkNormalizeProperties(
      {..._superProperties, ...?properties},
      onDroppedProperty: (path, reason) =>
          _logger.propertyDropped(path: path, reason: reason),
    );
  }

  Future<void> setOptOut(bool value) async {
    if (!_isStarted) {
      await start();
    }
    _isOptedOut = value;
    await _storage!.setOptOut(value);
    if (value) {
      _flushTimer?.cancel();
      _flushTimer = null;
      _foregroundSessionTimer?.cancel();
      _foregroundSessionTimer = null;
      _foregroundSessionActive = false;
      _queue.clear();
      _breadcrumbs.clear();
      await _persistQueue();
    } else {
      _startFlushTimer();
      await _enterForeground();
    }
    _logger.optOutChanged(value);
  }

  Future<void> flush() => _runFlush('manual');

  Future<void> _runFlush(String reason) {
    final activeFlush = _activeFlush;
    if (activeFlush != null) {
      return activeFlush;
    }

    final flush = _flush(reason);
    _activeFlush = flush;
    unawaited(
      flush.whenComplete(() {
        if (identical(_activeFlush, flush)) {
          _activeFlush = null;
        }
      }),
    );
    return flush;
  }

  Future<void> _flush(String reason) async {
    if (!_isStarted) {
      await start();
    }
    if (_isOptedOut || _queue.length == 0) {
      return;
    }

    _logger.flushStarted(reason: reason, pendingCount: _queue.length);
    final droppedBeforeSelection = _queue.droppedCount;
    final selection = _queue.takeBatch(
      context: _context,
      maxItems: 100,
      maxBytes: 256 * 1024,
      anonymousId: _anonymousId,
      now: clock.now(),
    );
    if (_queue.droppedCount > droppedBeforeSelection) {
      _logger.dropped(reason: 'item_too_large');
    }
    if (selection.items.isEmpty) {
      await _persistQueue();
      return;
    }

    final result = await _transport.send(
      RTKBatch(
        context: _context,
        anonymousId: _anonymousId,
        items: selection.items.map((item) => item.item).toList(),
      ),
    );
    _logger.transportResult(
      statusCode: result.statusCode,
      error: result.error,
      shouldRetry: result.shouldRetry,
    );
    final response = result.response;
    if (response != null) {
      _logger.batchResponse(response);
    }

    if (result.shouldRetry &&
        _retryPolicy.shouldRetry(
          statusCode: result.statusCode,
          error: result.error,
        )) {
      _markRetry(selection.items);
      await _persistQueue();
      return;
    }

    _queue.remove(selection.items);
    await _persistQueue();
  }

  RTKContext get _context => RTKContext(
        platform: config.runtimePlatform ?? _defaultPlatform,
        appVersion: config.appVersion,
        buildNumber: config.buildNumber,
        osName: config.osName ?? _deviceInfo.osName,
        osVersion: config.osVersion ?? _deviceInfo.osVersion,
        deviceModel: config.deviceModel ?? _deviceInfo.deviceModel,
        locale: config.locale ?? _defaultLocale,
      );

  Future<RTKResolvedDeviceInfo> _resolveDeviceInfo() async {
    if (config.osName != null &&
        config.osVersion != null &&
        config.deviceModel != null) {
      return const RTKResolvedDeviceInfo();
    }
    try {
      return await _deviceInfoProvider.resolve(
        platform: config.runtimePlatform ?? _defaultPlatform,
      );
    } catch (_) {
      return const RTKResolvedDeviceInfo();
    }
  }

  String get _defaultPlatform {
    if (kIsWeb) {
      return 'web';
    }
    return defaultTargetPlatform.name;
  }

  String? get _defaultLocale {
    final locale =
        WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
    if (locale.isEmpty) {
      return null;
    }
    return locale;
  }

  void _markRetry(List<RTKQueuedItem> items) {
    for (final item in items) {
      item.attemptCount += 1;
      if (!_retryPolicy.canAttempt(item.attemptCount)) {
        _queue.remove([item]);
        _logger.dropped(reason: 'max_retry_attempts');
        continue;
      }
      final delay = _retryPolicy.delayForAttempt(item.attemptCount - 1);
      item.nextRetryAt = clock.now().add(delay);
      _logger.retryScheduled(
        attemptCount: item.attemptCount,
        nextRetryAt: item.nextRetryAt!,
      );
    }
  }

  Future<void> _persistQueue() async {
    final storage = _storage;
    if (storage == null) {
      return;
    }
    final snapshot = _queue.items;
    _pendingPersist = _pendingPersist
        .catchError((_) {})
        .then((_) => storage.saveQueue(snapshot));
    await _pendingPersist;
  }

  Future<void> _enterForeground() async {
    if (!_shouldTrackForegroundDuration) {
      return;
    }
    if (_foregroundSessionActive) {
      await _checkpointForegroundSession();
      return;
    }
    await _enqueuePreviousForegroundSession();
    await _startForegroundSession();
  }

  Future<void> _leaveForeground() async {
    if (!_foregroundSessionActive) {
      return;
    }
    await _checkpointForegroundSession();
    _foregroundSessionActive = false;
    _foregroundSessionTimer?.cancel();
    _foregroundSessionTimer = null;
  }

  bool get _shouldTrackForegroundDuration {
    return config.enabled &&
        config.trackForegroundDuration &&
        !_isOptedOut &&
        _storage != null;
  }

  Future<void> _enqueuePreviousForegroundSession() async {
    final storage = _storage;
    if (storage == null) {
      return;
    }
    final session = await storage.loadForegroundSession();
    if (session == null) {
      return;
    }

    final endedAt = _maxTime(session.startedAt, session.lastSeenAt);
    _enqueue(
      RTKEvent(
        name: 'app_foreground_session',
        timestamp: endedAt,
        properties: {
          'duration_ms': endedAt.difference(session.startedAt).inMilliseconds,
          'started_at': rtkFormatTimestamp(session.startedAt),
          'ended_at': rtkFormatTimestamp(endedAt),
          'recovered': true,
        },
      ),
    );
    await _persistQueue();
    await storage.clearForegroundSession();
  }

  Future<void> _startForegroundSession() async {
    final storage = _storage;
    if (storage == null) {
      return;
    }
    final now = clock.now();
    await storage.saveForegroundSession(
      RTKForegroundSession(startedAt: now, lastSeenAt: now),
    );
    _foregroundSessionActive = true;
    _startForegroundSessionTimer();
  }

  Future<void> _checkpointForegroundSession() async {
    final storage = _storage;
    if (storage == null || !_shouldTrackForegroundDuration) {
      return;
    }
    final session = await storage.loadForegroundSession();
    if (session == null) {
      return;
    }
    final now = clock.now();
    final lastSeenAt = _maxTime(session.lastSeenAt, now);
    await storage.saveForegroundSession(
      session.copyWith(lastSeenAt: lastSeenAt),
    );
  }

  void _startForegroundSessionTimer() {
    _foregroundSessionTimer?.cancel();
    if (!_shouldTrackForegroundDuration) {
      return;
    }
    _foregroundSessionTimer = Timer.periodic(
      config.foregroundDurationCheckpointInterval,
      (_) {
        unawaited(_checkpointForegroundSession());
      },
    );
  }

  DateTime _maxTime(DateTime left, DateTime right) {
    return left.isAfter(right) ? left : right;
  }

  void _afterEnqueue() {
    if (!_isStarted) {
      return;
    }
    unawaited(_persistQueue());
    if (_queue.length >= config.flushAt) {
      _scheduleFlush('flushAt');
    }
  }

  void _scheduleFlush(String reason) {
    unawaited(_runFlush(reason));
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    if (!config.enabled || _isOptedOut) {
      return;
    }
    _flushTimer = Timer.periodic(config.flushInterval, (_) {
      if (_queue.length == 0) {
        return;
      }
      _scheduleFlush('flushInterval');
    });
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
    unawaited(_checkpointForegroundSession());
    _foregroundSessionTimer?.cancel();
    _foregroundSessionTimer = null;
    _foregroundSessionActive = false;
    _lifecycleBinding?.dispose();
    _lifecycleBinding = null;
    _transport.close();
  }
}

abstract final class RTK {
  static RenaRTK? _instance;

  static RenaRTK get instance {
    final client = _instance;
    if (client == null) {
      throw StateError('RTK has not been initialized.');
    }
    return client;
  }

  static Future<void> init(RTKConfig config) async {
    final client = RenaRTK(config: config);
    await client.start();
    _instance = client;
  }

  static void track(String name, {Map<String, Object?>? properties}) {
    _instance?.track(name, properties: properties);
  }

  static void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?>? properties,
  }) {
    _instance?.captureError(
      error,
      stackTrace: stackTrace,
      properties: properties,
    );
  }

  static void addBreadcrumb(String name, {Map<String, Object?>? properties}) {
    _instance?.addBreadcrumb(name, properties: properties);
  }

  static void setSuperProperties(Map<String, Object?> properties) {
    _instance?.setSuperProperties(properties);
  }

  static Future<void> flush() {
    return _instance?.flush() ?? Future<void>.value();
  }

  static Future<void> setOptOut(bool value) async {
    final client = _instance;
    if (client != null) {
      await client.setOptOut(value);
      return;
    }
    WidgetsFlutterBinding.ensureInitialized();
    final storage = await RTKStorage.create();
    await storage.setOptOut(value);
  }
}
