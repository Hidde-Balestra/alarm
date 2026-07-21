import 'package:alarm_app/l10n/gen/app_localizations.dart';
import 'package:alarm_app/models/alarm.dart';
import 'package:alarm_app/models/repeat_rule.dart';
import 'package:alarm_app/providers/providers.dart';
import 'package:alarm_app/widgets/weekday_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _snoozeOptions = [3, 5, 9, 10, 15, 20];

class AlarmEditScreen extends ConsumerStatefulWidget {
  final Alarm? alarm;

  const AlarmEditScreen({super.key, this.alarm});

  @override
  ConsumerState<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends ConsumerState<AlarmEditScreen> {
  late TimeOfDay _time;
  late TextEditingController _labelController;
  late RepeatType _repeatType;
  late Set<int> _weekdays;
  DateTime? _biweeklyAnchor;
  late bool _vibrate;
  late int _snoozeMinutes;

  bool get _isNew => widget.alarm == null;

  @override
  void initState() {
    super.initState();
    final alarm = widget.alarm;
    final defaults = ref.read(settingsProvider).valueOrNull;
    _time = TimeOfDay(hour: alarm?.hour ?? 7, minute: alarm?.minute ?? 0);
    _labelController = TextEditingController(text: alarm?.label ?? '');
    _repeatType = alarm?.repeat.type ?? RepeatType.none;
    _weekdays = {...(alarm?.repeat.weekdays ?? const {})};
    _biweeklyAnchor = alarm?.repeat.anchorDate;
    _vibrate = alarm?.vibrate ?? defaults?.defaultVibrate ?? true;
    _snoozeMinutes = alarm?.snoozeMinutes ?? defaults?.defaultSnoozeMinutes ?? 9;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  RepeatRule _buildRepeatRule() {
    switch (_repeatType) {
      case RepeatType.none:
        return const RepeatRule.none();
      case RepeatType.daily:
        return const RepeatRule.daily();
      case RepeatType.weekly:
        return RepeatRule.weekly(_weekdays);
      case RepeatType.biweekly:
        return RepeatRule.biweekly(_weekdays, _biweeklyAnchor ?? DateTime.now());
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if ((_repeatType == RepeatType.weekly || _repeatType == RepeatType.biweekly) &&
        _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.repeatSectionTitle)),
      );
      return;
    }

    final notifier = ref.read(alarmsProvider.notifier);
    final alarm = Alarm(
      id: widget.alarm?.id ?? notifier.newAlarmId(),
      hour: _time.hour,
      minute: _time.minute,
      label: _labelController.text.trim(),
      enabled: widget.alarm?.enabled ?? true,
      repeat: _buildRepeatRule(),
      vibrate: _vibrate,
      snoozeMinutes: _snoozeMinutes,
    );
    await notifier.upsert(alarm);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final alarm = widget.alarm;
    if (alarm == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteAlarmConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(alarmsProvider.notifier).remove(alarm.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.newAlarmTitle : l10n.editAlarmTitle),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.delete,
              onPressed: _delete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: l10n.save,
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: TextButton(
              onPressed: _pickTime,
              child: Text(
                _time.format(context),
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: l10n.labelFieldHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.repeatSectionTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<RepeatType>(
            segments: [
              ButtonSegment(value: RepeatType.none, label: Text(l10n.repeatNever)),
              ButtonSegment(value: RepeatType.daily, label: Text(l10n.repeatDaily)),
              ButtonSegment(value: RepeatType.weekly, label: Text(l10n.repeatWeekly)),
              ButtonSegment(value: RepeatType.biweekly, label: Text(l10n.repeatBiweekly)),
            ],
            selected: {_repeatType},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() {
                _repeatType = selection.first;
                if (_repeatType == RepeatType.biweekly) {
                  _biweeklyAnchor ??= DateTime.now();
                }
              });
            },
          ),
          if (_repeatType == RepeatType.weekly || _repeatType == RepeatType.biweekly) ...[
            const SizedBox(height: 16),
            WeekdayPicker(
              selected: _weekdays,
              onChanged: (value) => setState(() => _weekdays = value),
            ),
          ],
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.vibrationLabel),
            value: _vibrate,
            onChanged: (value) => setState(() => _vibrate = value),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.snoozeDurationLabel),
            trailing: DropdownButton<int>(
              value: _snoozeMinutes,
              items: [
                for (final minutes in _snoozeOptions)
                  DropdownMenuItem(value: minutes, child: Text(l10n.minutesShort(minutes))),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _snoozeMinutes = value);
              },
            ),
          ),
        ],
      ),
    );
  }
}
