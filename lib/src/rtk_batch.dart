import 'rtk_context.dart';
import 'rtk_event.dart';

class RTKBatch {
  RTKBatch({
    required this.context,
    required this.items,
    this.anonymousId,
    this.sessionId,
  });

  final RTKContext context;
  final String? anonymousId;
  final String? sessionId;
  final List<RTKBatchItem> items;

  Map<String, Object?> toJson() {
    return {
      'context': context.toJson(),
      if (anonymousId != null) 'anonymous_id': anonymousId,
      if (sessionId != null) 'session_id': sessionId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
