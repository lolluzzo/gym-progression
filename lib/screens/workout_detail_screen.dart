import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gym_progression/models/achievement.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/screens/exercise_history_logs.dart';
import 'package:gym_progression/services/app_settings.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
import 'package:gym_progression/services/training_sessions.dart';
import 'package:gym_progression/utils/exercise_name.dart';
import 'package:gym_progression/utils/week.dart';
import 'package:gym_progression/widgets/celebration.dart';
import 'package:gym_progression/widgets/dialogs.dart';
import 'package:gym_progression/widgets/set_row.dart';
import 'package:gym_progression/widgets/sets_guide.dart';
import 'package:gym_progression/widgets/weight_progress_chart.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    required this.profileId,
  });

  final Workout workout;
  final String profileId;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

/// One row on an exercise card. [logId] is null until the set is saved.
class _SetRowData {
  _SetRowData({
    this.logId,
    String weight = '',
    String reps = '',
    this.isWarmup = false,
  })  : weight = TextEditingController(text: weight),
        reps = TextEditingController(text: reps),
        saved = logId == null ? null : (weight.trim(), reps.trim(), isWarmup);

  _SetRowData.fromLog(ExerciseLogEntry log)
      : this(
          logId: log.id,
          weight: log.weight ?? '',
          reps: log.reps ?? '',
          isWarmup: log.isWarmup,
        );

  int? logId;
  final TextEditingController weight;
  final TextEditingController reps;
  bool isWarmup;

  /// The values last saved. Editing a saved set makes it pending again.
  (String, String, bool)? saved;

  (String, String, bool) get _values =>
      (weight.text.trim(), reps.text.trim(), isWarmup);

  bool get hasValue => _values.$1.isNotEmpty || _values.$2.isNotEmpty;

  /// An empty new row, like the one at the end of every card.
  bool get isBlank => !hasValue && !isWarmup && logId == null;

  bool get isSaved => logId != null && _values == saved;

  /// A typed set to insert, an edited set to update, or a saved set whose
  /// values were cleared, to delete.
  bool get isPending => logId == null ? hasValue : _values != saved;

  SetRowState get state => isSaved
      ? SetRowState.saved
      : hasValue || logId != null
          ? SetRowState.typed
          : SetRowState.empty;

  void markSaved(int id) {
    logId = id;
    saved = _values;
  }

  void markDeleted() {
    logId = null;
    saved = null;
  }

  void dispose() {
    weight.dispose();
    reps.dispose();
  }
}

typedef _Record = ({double weight, double previous});

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Workout _workout;

  // All keyed by the exerciseKey of a form.
  final Map<String, List<_SetRowData>> _rows = {};
  final Map<String, List<int>> _removedIds = {};
  Map<String, double> _bestWeights = {};

  /// The best working set before today's session of this workout.
  Map<String, double> _earlierBests = {};
  Map<String, TrainingSession> _lastSessions = {};

  bool _isSaving = false;

  String get _currentWeekKey => weekKeyFor(DateTime.now());

  bool get _isCompletedThisWeek =>
      _workout.lastCompletedWeekKey == _currentWeekKey;

  int get _pendingCount {
    var count = 0;
    for (final MapEntry(:key, value: rows) in _rows.entries) {
      count += rows.where((row) => row.isPending).length +
          (_removedIds[key]?.length ?? 0);
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
    _loadLogs(reloadRows: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showGuideOnce());
  }

  @override
  void dispose() {
    for (final rows in _rows.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _showGuideOnce() async {
    final settings = AppSettings.instance;
    if (!mounted || settings.setsGuideSeen) {
      return;
    }

    await settings.markSetsGuideSeen();
    if (mounted) {
      await showSetsGuide(context);
    }
  }

  /// Saves every pending set, then returns the workout from [update].
  Future<void> _saveAndClose(Workout Function() update) async {
    setState(() => _isSaving = true);

    final List<String> records;
    try {
      records = await _saveAllPending();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save the sets.')),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    if (records.isNotEmpty) {
      await showCelebration(
        context,
        icon: Icons.emoji_events_rounded,
        title: 'New personal record!',
        message: records.join('\n'),
      );
    }
    if (mounted) {
      Navigator.of(context).pop(update());
    }
  }

  void _saveWorkoutProgress() {
    _saveAndClose(() => _workout.copyWith(updatedAt: DateTime.now()));
  }

  void _markWorkoutComplete() {
    _saveAndClose(
      () => _workout.copyWith(
        updatedAt: DateTime.now(),
        lastCompletedWeekKey: _currentWeekKey,
      ),
    );
  }

  void _markWorkoutToDoAgain() {
    _saveAndClose(
      () => _workout.copyWith(
        updatedAt: DateTime.now(),
        clearCompletedWeek: true,
      ),
    );
  }

  void _chooseForm(ExerciseEntry exercise, String form) {
    setState(() {
      _workout = _workout.copyWith(
        exercises: [
          for (final item in _workout.exercises)
            item.id == exercise.id ? item.copyWith(chosenName: form) : item,
        ],
      );
    });
  }

  /// Loads the Best chips, last time's sets and the earlier bests. With
  /// [reloadRows], each form without pending changes also shows today's
  /// saved sets again.
  Future<void> _loadLogs({bool reloadRows = false}) async {
    final logs = await ExerciseLogStorage.getLogsForProfile(widget.profileId);
    final todaysSets = await ExerciseLogStorage.getSetsForDay(
      widget.profileId,
      _workout.id,
      DateTime.now(),
    );
    final todaysIds = {for (final log in todaysSets) log.id};

    final bestWeights = <String, double>{};
    final earlierBests = <String, double>{};
    final earlierLogs = <String, List<ExerciseLogEntry>>{};
    for (final log in logs) {
      final key = exerciseKey(log.exerciseName);
      final weight = log.isWarmup ? null : parseMetric(log.weight);
      if (weight != null) {
        bestWeights[key] = math.max(bestWeights[key] ?? weight, weight);
      }
      if (todaysIds.contains(log.id)) {
        continue;
      }
      earlierLogs.putIfAbsent(key, () => []).add(log);
      if (weight != null) {
        earlierBests[key] = math.max(earlierBests[key] ?? weight, weight);
      }
    }

    final todaysByKey = <String, List<ExerciseLogEntry>>{};
    for (final log in todaysSets) {
      todaysByKey.putIfAbsent(exerciseKey(log.exerciseName), () => []).add(log);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _bestWeights = bestWeights;
      _earlierBests = earlierBests;
      _lastSessions = {
        for (final MapEntry(:key, value: logs) in earlierLogs.entries)
          key: groupSessions(logs).first,
      };

      if (reloadRows) {
        for (final key in {..._rows.keys, ...todaysByKey.keys}) {
          if (_hasPending(key)) {
            continue;
          }
          _rows[key]?.forEach(_disposeLater);
          _rows[key] = [
            for (final log in todaysByKey[key] ?? const <ExerciseLogEntry>[])
              _SetRowData.fromLog(log),
          ];
          _keepOneEmptyRow(_rows[key]!);
        }
      }
    });
  }

  List<_SetRowData> _rowsFor(String form) {
    return _rows.putIfAbsent(exerciseKey(form), () => [_SetRowData()]);
  }

  bool _hasPending(String key) {
    return (_removedIds[key]?.isNotEmpty ?? false) ||
        (_rows[key]?.any((row) => row.isPending) ?? false);
  }

  /// The last row is always empty: typing in it adds the next one.
  void _keepOneEmptyRow(List<_SetRowData> rows) {
    var end = rows.length;
    while (end > 0 && rows[end - 1].isBlank) {
      end--;
    }
    if (end == rows.length) {
      rows.add(_SetRowData());
      return;
    }
    rows.sublist(end + 1).forEach(_disposeLater);
    rows.removeRange(end + 1, rows.length);
  }

  /// The row's fields can still be on screen until the next frame.
  void _disposeLater(_SetRowData row) {
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _removeRow(List<_SetRowData> rows, String key, _SetRowData row) {
    setState(() {
      rows.remove(row);
      if (row.logId case final id?) {
        _removedIds.putIfAbsent(key, () => []).add(id);
      }
      _disposeLater(row);
      _keepOneEmptyRow(rows);
    });
  }

  /// Grey hints for each row: the nearest working set above it, or for the
  /// first one, the first working set of last time. A warm-up gets last
  /// time's first warm-up. Hints are never saved.
  List<(String?, String?)> _hintsFor(String key, List<_SetRowData> rows) {
    final lastSets = _lastSessions[key]?.logs ?? const <ExerciseLogEntry>[];
    final lastWorking = lastSets.where((log) => !log.isWarmup).firstOrNull;
    final lastWarmup = lastSets.where((log) => log.isWarmup).firstOrNull;

    var above = (lastWorking?.weight, lastWorking?.reps);
    final hints = <(String?, String?)>[];
    for (final row in rows) {
      if (row.isWarmup) {
        hints.add(
          lastWarmup == null ? above : (lastWarmup.weight, lastWarmup.reps),
        );
        continue;
      }

      hints.add(above);
      if (row.hasValue) {
        final weight = row.weight.text.trim();
        final reps = row.reps.text.trim();
        above = (
          weight.isEmpty ? above.$1 : weight,
          reps.isEmpty ? above.$2 : reps,
        );
      }
    }
    return hints;
  }

  double? _topSavedWeight(List<_SetRowData> rows) {
    double? top;
    for (final row in rows) {
      final saved = row.saved;
      if (saved == null || saved.$3) {
        continue;
      }
      final weight = parseMetric(saved.$1);
      if (weight != null) {
        top = math.max(top ?? weight, weight);
      }
    }
    return top;
  }

  /// Saves the pending sets of [form] in one transaction. Returns the top
  /// set when it beats every earlier session and today's sets before it.
  Future<_Record?> _saveForm(String form) async {
    final key = exerciseKey(form);
    final rows = _rows[key];
    if (rows == null) {
      return null;
    }
    final pending = rows.where((row) => row.isPending).toList();
    final removedIds = _removedIds[key] ?? const <int>[];
    if (pending.isEmpty && removedIds.isEmpty) {
      return null;
    }

    final topBefore = _topSavedWeight(rows);
    final toSave = pending.where((row) => row.hasValue).toList();
    final cleared = pending.where((row) => !row.hasValue).toList();
    final ids = await ExerciseLogStorage.saveSets(
      profileId: widget.profileId,
      exerciseName: form,
      sets: [
        for (final row in toSave)
          SetToSave(
            id: row.logId,
            weight: row.weight.text,
            reps: row.reps.text,
            isWarmup: row.isWarmup,
          ),
      ],
      deletedIds: [...removedIds, for (final row in cleared) row.logId!],
      workoutId: _workout.id,
      workoutName: _workout.name,
    );

    for (final (index, row) in toSave.indexed) {
      row.markSaved(ids[index]);
    }
    for (final row in cleared) {
      row.markDeleted();
    }
    _removedIds.remove(key);
    // Empty rows left between sets go. The last one stays for the next set.
    for (var index = rows.length - 2; index >= 0; index--) {
      if (rows[index].isBlank) {
        _disposeLater(rows.removeAt(index));
      }
    }
    if (mounted) {
      setState(() => _keepOneEmptyRow(rows));
    }

    final topAfter = _topSavedWeight(rows);
    final previous = _earlierBests[key];
    final isRecord = topAfter != null &&
        previous != null &&
        topAfter > previous &&
        (topBefore == null || topAfter > topBefore);
    return isRecord ? (weight: topAfter, previous: previous) : null;
  }

  /// Saves the pending sets of every form. Returns the PR messages.
  Future<List<String>> _saveAllPending() async {
    final records = <String>[];
    for (final exercise in _workout.exercises) {
      for (final form in exercise.forms) {
        if (await _saveForm(form) case final record?) {
          records.add(_recordMessage(form, record));
        }
      }
    }
    await _loadLogs();
    return records;
  }

  String _recordMessage(String form, _Record record) {
    return '$form: ${formatNumber(record.weight)} kg, '
        'up from ${formatNumber(record.previous)} kg.';
  }

  Future<void> _saveExercise(String form) async {
    setState(() => _isSaving = true);

    try {
      final statsBefore = await ProfileStats.load(widget.profileId);
      final record = await _saveForm(form);
      final statsAfter = await ProfileStats.load(widget.profileId);
      final unlocked = newlyUnlocked(statsBefore, statsAfter);
      await _loadLogs();

      if (!mounted) {
        return;
      }

      if (record != null) {
        await showCelebration(
          context,
          icon: Icons.emoji_events_rounded,
          title: 'New personal record!',
          message: _recordMessage(form, record),
          unlocked: unlocked,
        );
        return;
      }

      if (unlocked.isNotEmpty) {
        await showCelebration(
          context,
          icon: unlocked.first.icon,
          title: 'Sets saved',
          message: 'Saved $form.',
          unlocked: unlocked,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved $form.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save the sets.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openExerciseHistory(ExerciseEntry exercise) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseHistoryLogsScreen(
          profileId: widget.profileId,
          exerciseName: exercise.activeName,
        ),
      ),
    );
    // Logs may have been deleted or moved there.
    if (mounted) {
      await _loadLogs(reloadRows: true);
    }
  }

  Future<void> _confirmDiscard() async {
    final count = _pendingCount;
    final discard = await showConfirmDialog(
      context,
      title: 'Discard unsaved sets?',
      message: count == 1
          ? '1 set is not saved yet. Going back drops it.'
          : '$count sets are not saved yet. Going back drops them.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
    );
    if (discard && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _formatDay(DateTime day) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(day.day)}/${twoDigits(day.month)}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _pendingCount == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmDiscard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_workout.name),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'How to log sets',
              onPressed: () => showSetsGuide(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Card(
              color:
                  _isCompletedThisWeek ? Colors.green.withOpacity(0.12) : null,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCompletedThisWeek
                          ? 'Completed for this week'
                          : 'Still to complete this week',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCompletedThisWeek
                          ? 'This workout will automatically become active again next week.'
                          : 'Save your sets, then mark the workout as completed when you finish it.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveWorkoutProgress,
                          icon: const Icon(Icons.save),
                          label: const Text('Save progress'),
                        ),
                        if (!_isCompletedThisWeek)
                          FilledButton.tonalIcon(
                            onPressed: _isSaving ? null : _markWorkoutComplete,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Complete workout'),
                          ),
                        if (_isCompletedThisWeek)
                          OutlinedButton.icon(
                            onPressed: _isSaving ? null : _markWorkoutToDoAgain,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Mark as to do'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            for (final exercise in _workout.exercises)
              _buildExerciseCard(exercise),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(ExerciseEntry exercise) {
    final theme = Theme.of(context);
    final form = exercise.activeName;
    final key = exerciseKey(form);
    final rows = _rowsFor(form);
    final hints = _hintsFor(key, rows);
    final lastSession = _lastSessions[key];
    var number = 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(form, style: theme.textTheme.titleMedium),
                ),
                if (_bestWeights[key] case final best?)
                  _BestWeightChip(weight: best),
              ],
            ),
            if (exercise.alternatives.isNotEmpty) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final option in exercise.forms)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(option),
                              // This form has sets that aren't saved.
                              if (option != form &&
                                  _hasPending(exerciseKey(option))) ...[
                                const SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 3.5,
                                  backgroundColor: theme.colorScheme.primary,
                                ),
                              ],
                            ],
                          ),
                          selected: option == form,
                          onSelected: (_) => _chooseForm(exercise, option),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (lastSession != null) ...[
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  children: [
                    TextSpan(
                      text: 'Last time · ${_formatDay(lastSession.day)}   ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    setsLineSpan(context, lastSession.logs),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const SetRowHeader(),
            for (final (index, row) in rows.indexed)
              Padding(
                key: ObjectKey(row),
                padding: const EdgeInsets.only(top: 8),
                child: SetRow(
                  label: row.isWarmup ? 'W' : '${++number}',
                  state: row.state,
                  isWarmup: row.isWarmup,
                  weight: row.weight,
                  reps: row.reps,
                  weightHint: hints[index].$1,
                  repsHint: hints[index].$2,
                  onChanged: () => setState(() => _keepOneEmptyRow(rows)),
                  onToggleWarmup: () => setState(() {
                    row.isWarmup = !row.isWarmup;
                    _keepOneEmptyRow(rows);
                  }),
                  onRemove: row.hasValue || row.isWarmup || row.logId != null
                      ? () => _removeRow(rows, key, row)
                      : null,
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildSaveButton(form, key, rows),
                OutlinedButton.icon(
                  onPressed: () => _openExerciseHistory(exercise),
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(String form, String key, List<_SetRowData> rows) {
    final pending = rows.where((row) => row.isPending).toList();
    final sets = pending.where((row) => row.hasValue).length;
    final deletions =
        pending.length - sets + (_removedIds[key]?.length ?? 0);

    if (sets == 0 && deletions == 0) {
      final anySaved = rows.any((row) => row.logId != null);
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: Icon(anySaved ? Icons.check : Icons.save_outlined),
        label: Text(anySaved ? 'Saved' : 'Save'),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: _isSaving ? null : () => _saveExercise(form),
      icon: const Icon(Icons.save_outlined),
      label: Text(
        deletions > 0
            ? 'Save changes'
            : 'Save $sets ${sets == 1 ? 'set' : 'sets'}',
      ),
    );
  }
}

class _BestWeightChip extends StatelessWidget {
  const _BestWeightChip({required this.weight});

  final double weight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordColor = ChartColors.record(theme.brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: recordColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 16, color: recordColor),
          const SizedBox(width: 4),
          Text(
            'Best ${formatNumber(weight)} kg',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
