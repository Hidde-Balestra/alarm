import 'package:home_widget/home_widget.dart';

/// Pushes the next-alarm summary to the Android homescreen widget
/// (`AlarmWidgetProvider`). No-op on platforms without that widget (iOS).
///
/// Kept as an instance (not static calls) so it can be swapped for a fake in
/// widget tests via Riverpod provider overrides — same pattern as the other
/// services in this app.
class HomeWidgetService {
  static const _timeKey = 'next_alarm_time';
  static const _labelKey = 'next_alarm_label';
  static const _androidWidgetName = 'AlarmWidgetProvider';

  /// [timeText] and [labelText] should already be formatted for display
  /// (e.g. via the app's own time/locale formatting); pass null for both
  /// when there's no upcoming alarm to show.
  Future<void> updateNextAlarm({String? timeText, String? labelText}) async {
    await HomeWidget.saveWidgetData<String>(_timeKey, timeText ?? '');
    await HomeWidget.saveWidgetData<String>(_labelKey, labelText ?? '');
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }
}
