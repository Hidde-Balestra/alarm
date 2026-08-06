import 'package:alarm_app/services/alarm_scheduler_service.dart';

/// What happened to an alarm or timer, for the history log.
enum HistoryAction { rang, snoozed, dismissed }

/// A single logged event ("this alarm rang at 07:00, then got snoozed, then
/// dismissed at 07:12") so a user can look back at their own patterns.
class HistoryEntry {
  final String id;
  final RingingKind kind;
  final String refId;
  final String label;
  final HistoryAction action;
  final DateTime timestamp;

  const HistoryEntry({
    required this.id,
    required this.kind,
    required this.refId,
    required this.action,
    required this.timestamp,
    this.label = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'refId': refId,
        'label': label,
        'action': action.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        kind: RingingKind.values.byName(json['kind'] as String),
        refId: json['refId'] as String,
        label: json['label'] as String? ?? '',
        action: HistoryAction.values.byName(json['action'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
