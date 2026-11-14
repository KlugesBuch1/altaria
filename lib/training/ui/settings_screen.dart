import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme.dart';
import '../models.dart';
import '../training_scope.dart';
import 'format.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _bar = TextEditingController();
  List<double> _plates = const [];
  bool _loaded = false;
  bool _working = false;
  bool _notificationBusy = false;

  static const _kgPlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25, 0.5];
  static const _lbPlates = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5, 1.25];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final store = TrainingScope.of(context);
    _syncFrom(store.settings);
    unawaited(store.refreshNotificationPermission());
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  void _syncFrom(TrainingSettings settings) {
    _bar.text = _number(settings.barWeight);
    _plates = [...settings.plateInventory];
    if (mounted) setState(() {});
  }

  Future<void> _changeUnit(WeightUnit unit) async {
    final store = TrainingScope.of(context);
    if (store.settings.unit == unit) return;
    final next = store.settings.withUnit(unit);
    await store.saveSettings(next);
    if (!mounted) return;
    setState(() => _syncFrom(next));
  }

  Future<void> _savePlates() async {
    final store = TrainingScope.of(context);
    final bar = _parseNumber(_bar.text);
    if (bar <= 0) {
      _toast('Enter a bar weight above zero.');
      return;
    }
    if (_plates.isEmpty) {
      _toast('Keep at least one plate size available.');
      return;
    }
    final next = store.settings.withBarWeight(bar).withPlates(_plates);
    await store.saveSettings(next);
    if (!mounted) return;
    _toast('Plate setup saved.');
  }

  Future<void> _editRest() async {
    final store = TrainingScope.of(context);
    final controller = TextEditingController(
      text: '${store.settings.defaultRestSeconds}',
    );
    final seconds = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panelHigh,
        title: const Text('Default rest'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: 'seconds',
            hintText: '90',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 0 || value > 900) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (seconds == null || !mounted) return;
    await store.saveSettings(
      store.settings.copyWith(defaultRestSeconds: seconds),
    );
  }

  Future<void> _setKeepAwake(bool value) async {
    final store = TrainingScope.of(context);
    await store.saveSettings(store.settings.copyWith(keepAwake: value));
  }

  Future<void> _setNotifications(bool value) async {
    if (_notificationBusy) return;
    setState(() => _notificationBusy = true);
    final store = TrainingScope.of(context);
    final enabled = await store.setRestNotifications(value);
    if (!mounted) return;
    setState(() => _notificationBusy = false);
    if (value && !enabled) {
      _toast('Notifications are blocked. The in-app rest timer still works.');
    }
  }

  Future<void> _exportJson() async {
    await _run(() async {
      final store = TrainingScope.of(context);
      final content = await store.exportJson();
      await _shareFile(
        content: content,
        filename: 'altaria-backup-${_dateStamp()}.json',
        subject: 'altaria backup',
      );
    });
  }

  Future<void> _exportCsv() async {
    await _run(() async {
      final store = TrainingScope.of(context);
      final content = await store.exportCsv();
      await _shareFile(
        content: content,
        filename: 'altaria-workouts-${_dateStamp()}.csv',
        subject: 'altaria workout export',
      );
    });
  }

  Future<void> _importJson() async {
    final confirmed = await confirmAction(
      context,
      title: 'Import a backup?',
      message:
          'The routines, workouts, settings and custom movements in the file '
          'replace what is on this device.',
      confirmLabel: 'Choose file',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      final content = utf8.decode(await file.readAsBytes());
      if (!mounted) return;
      await TrainingScope.of(context).importBackup(content);
      if (!mounted) return;
      _syncFrom(TrainingScope.of(context).settings);
      _toast('Backup imported.');
    });
  }

  Future<void> _reset() async {
    final confirmed = await confirmAction(
      context,
      title: 'Reset local training data?',
      message:
          'Workouts, routines, records, body metrics and settings are deleted '
          'from this device. The music catalogue is not touched.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      await TrainingScope.of(context).resetLocalData();
      if (!mounted) return;
      _syncFrom(TrainingScope.of(context).settings);
      _toast('Training data reset.');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _toast('$error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _shareFile({
    required String content,
    required String filename,
    required String subject,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, filename));
    await file.writeAsString(content);
    if (!mounted) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    final origin = renderBox == null
        ? null
        : renderBox.localToGlobal(Offset.zero) & renderBox.size;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final store = TrainingScope.of(context);
    final settings = store.settings;
    final unit = settings.unit;
    final candidatePlates = <double>{
      ...(unit == WeightUnit.kg ? _kgPlates : _lbPlates),
      ..._plates,
    }.toList()..sort((a, b) => b.compareTo(a));
    final permission = store.notificationsGranted;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const TrainingSectionTitle(title: 'Units'),
          const SizedBox(height: 10),
          TrainingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in WeightUnit.values)
                      ChoiceChip(
                        label: Text(item.storage),
                        selected: unit == item,
                        showCheckmark: false,
                        backgroundColor: panelHigh,
                        selectedColor: wine,
                        side: BorderSide(
                          color: unit == item ? ember : hairline,
                        ),
                        onSelected: (_) => _changeUnit(item),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Stored as kg, displayed in your unit.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: muted),
                ),
                const SizedBox(height: 16),
                SectionDivider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Default rest',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: cream),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatRest(settings.defaultRestSeconds)} between sets',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _editRest,
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  key: const Key('keep-awake'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Keep screen awake',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: cream),
                  ),
                  subtitle: Text(
                    'Only while a workout is open.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: muted),
                  ),
                  value: settings.keepAwake,
                  activeThumbColor: ember,
                  activeTrackColor: wine,
                  onChanged: _setKeepAwake,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const TrainingSectionTitle(title: 'Rest notifications'),
          const SizedBox(height: 10),
          TrainingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  key: const Key('rest-notifications'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Notify when rest ends',
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: cream),
                  ),
                  subtitle: Text(
                    permission == null
                        ? 'Uses a separate notification channel from music.'
                        : permission
                        ? 'Allowed. Uses a separate channel from music.'
                        : 'Not allowed yet. The in-app timer still works.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: permission == false ? rose : muted),
                  ),
                  value: settings.restNotifications && permission != false,
                  activeThumbColor: ember,
                  activeTrackColor: wine,
                  onChanged: _notificationBusy ? null : _setNotifications,
                ),
                if (permission == false)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _notificationBusy
                          ? null
                          : () async {
                              final granted = await store
                                  .requestNotificationPermission();
                              if (!mounted) return;
                              await store.refreshNotificationPermission();
                              if (granted) await _setNotifications(true);
                            },
                      child: const Text('Allow notifications'),
                    ),
                  ),
                Text(
                  'Rest alerts never claim audio focus and never pause the player.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: muted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          TrainingSectionTitle(
            title: 'Bar & plates',
            action: Text(
              unit.storage,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: ember, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 10),
          TrainingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 128,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FieldLabel('Bar (${unit.storage})'),
                          TextField(
                            key: const Key('bar-weight'),
                            controller: _bar,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(hintText: '20'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap the pair sizes you keep on the rack. '
                        'Each selected size counts as one pair.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: muted, height: 1.35),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final plate in candidatePlates)
                      FilterChip(
                        label: Text(_number(plate)),
                        selected: _plates.contains(plate),
                        showCheckmark: false,
                        backgroundColor: panelHigh,
                        selectedColor: wine,
                        side: BorderSide(
                          color: _plates.contains(plate) ? ember : hairline,
                        ),
                        labelStyle: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: cream),
                        onSelected: (selected) {
                          setState(() {
                            _plates = [..._plates];
                            if (selected) {
                              _plates.add(plate);
                            } else {
                              _plates.remove(plate);
                            }
                            _plates.sort((a, b) => b.compareTo(a));
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _savePlates,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save bar & plates'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const TrainingSectionTitle(title: 'Backup & data'),
          const SizedBox(height: 10),
          TrainingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everything is local. Export a full JSON backup or a CSV of '
                  'finished workouts through the share sheet.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _exportJson,
                        icon: const Icon(Icons.archive_outlined, size: 18),
                        label: const Text('JSON backup'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _exportCsv,
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: const Text('CSV export'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _importJson,
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    label: const Text('Import JSON backup'),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _working ? null : _reset,
                    child: Text(
                      'Reset local training data',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
                if (_working)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No account. No cloud sync. No feature behind a purchase.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

double _parseNumber(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

String _number(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

String _dateStamp() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}
