import 'package:flutter/material.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
import 'package:gym_progression/services/training_sessions.dart';
import 'package:gym_progression/services/workout_storage.dart';
import 'package:gym_progression/utils/exercise_name.dart';
import 'package:gym_progression/widgets/dialogs.dart';
import 'package:gym_progression/widgets/weight_progress_chart.dart';

class ExerciseHistoryLogsScreen extends StatefulWidget {
  const ExerciseHistoryLogsScreen({
    super.key,
    required this.profileId,
    required this.exerciseName,
  });

  final String profileId;
  final String exerciseName;

  @override
  State<ExerciseHistoryLogsScreen> createState() =>
      _ExerciseHistoryLogsScreenState();
}

enum _LogsAction { move, deleteAll }

class _ExerciseHistoryLogsScreenState extends State<ExerciseHistoryLogsScreen> {
  late Future<List<ExerciseLogEntry>> _logsFuture;
  bool _hasLogs = false;

  @override
  void initState() {
    super.initState();
    _logsFuture = _loadLogs();
  }

  Future<List<ExerciseLogEntry>> _loadLogs() async {
    final logs = await ExerciseLogStorage.getLogsForExercise(
      widget.profileId,
      widget.exerciseName,
    );
    if (mounted) {
      setState(() => _hasLogs = logs.isNotEmpty);
    }

    return logs;
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _logsFuture = _loadLogs();
    });

    await _logsFuture;
  }

  /// Asks, then deletes the set. Returns false so a swiped row slides back:
  /// the reloaded list no longer has it.
  Future<bool> _deleteLog(ExerciseLogEntry entry) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete set?',
      message:
          'The set from ${_formatLoggedAt(entry.loggedAt)} will be removed.',
    );
    if (confirmed) {
      await _deleteLogs([entry.id], 'Unable to delete the set.');
    }
    return false;
  }

  Future<void> _deleteSession(TrainingSession session) async {
    final count = session.logs.length;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete session?',
      message:
          '${count == 1 ? 'Its set' : 'All $count sets'} of ${_formatDay(session.day)} will be removed.',
    );
    if (confirmed) {
      await _deleteLogs(
        [for (final log in session.logs) log.id],
        'Unable to delete the session.',
      );
    }
  }

  Future<void> _deleteLogs(List<int> ids, String errorMessage) async {
    try {
      for (final id in ids) {
        await ExerciseLogStorage.deleteLog(id);
      }
      if (!mounted) {
        return;
      }

      await _refreshLogs();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  String _logCount(int count) => count == 1 ? '1 log' : '$count logs';

  /// Moves every log to an exercise of the profile's workouts, then closes
  /// the screen.
  Future<void> _moveLogs() async {
    final currentKey = exerciseKey(widget.exerciseName);
    final workouts = await WorkoutStorage.loadWorkouts(widget.profileId);
    final groups = [
      for (final workout in workouts)
        (
          workout: workout.name,
          forms: [
            for (final exercise in workout.exercises)
              for (final form in exercise.forms)
                if (exerciseKey(form) != currentKey) form,
          ],
        ),
    ].where((group) => group.forms.isNotEmpty).toList();
    if (!mounted) {
      return;
    }

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other exercises in your workouts.')),
      );
      return;
    }

    final target = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                group.workout,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            for (final form in group.forms)
              ListTile(
                title: Text(form),
                onTap: () => Navigator.of(context).pop(form),
              ),
          ],
        ],
      ),
    );
    if (target == null || !mounted) {
      return;
    }

    final count = (await _logsFuture).length;
    if (!mounted) {
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Move logs to $target?',
      message:
          '${_logCount(count)} of ${widget.exerciseName} will join the history of $target.',
      confirmLabel: 'Move logs',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final moved = await ExerciseLogStorage.renameExercise(
        widget.profileId,
        widget.exerciseName,
        target,
      );
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Moved ${_logCount(moved)} to $target.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to move the logs.')),
      );
    }
  }

  Future<void> _deleteAllLogs() async {
    final count = (await _logsFuture).length;
    if (!mounted) {
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete all logs?',
      message:
          'All ${_logCount(count)} of ${widget.exerciseName} will be removed.',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final deleted = await ExerciseLogStorage.deleteLogsForExercise(
        widget.profileId,
        widget.exerciseName,
      );
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Deleted ${_logCount(deleted)}.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to delete the logs.')),
      );
    }
  }

  /// "80 kg × 8", "× 12" without weight, "80 kg" without reps.
  String _formatSet(ExerciseLogEntry log) {
    final parts = [
      if (log.weight != null) '${log.weight} kg',
      if (log.reps != null) '× ${log.reps}',
    ];
    return parts.isEmpty ? 'No values' : parts.join(' ');
  }

  String _formatDay(DateTime day) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(day.day)}/${twoDigits(day.month)}/${day.year}';
  }

  String _formatLoggedAt(DateTime loggedAt) {
    final local = loggedAt.toLocal();

    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} • ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  Widget _buildStatusState({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Icon(icon,
              size: 56, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[
          const SizedBox(height: 20),
          Center(child: action),
        ],
      ],
    );
  }

  /// Best / latest / PR tiles and the weight chart, above the sessions.
  Widget _buildSummary(
    List<ExerciseLogEntry> logs,
    int sessionCount,
    Set<int> recordIds,
  ) {
    final theme = Theme.of(context);
    // One point per session: its top set, oldest first.
    final weightedLogs = topSets(logs);
    final best = bestWeight(logs);
    final latest =
        weightedLogs.isEmpty ? null : parseMetric(weightedLogs.last.weight);

    String weightLabel(double? value) =>
        value == null ? 'Not set' : '${formatNumber(value)} kg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(label: 'Best', value: weightLabel(best)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(label: 'Latest', value: weightLabel(latest)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricTile(label: 'PRs', value: '${recordIds.length}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
            child: weightedLogs.length >= 2
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weight progress', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      WeightProgressChart(
                        logs: weightedLogs,
                        recordIds: recordIds,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.show_chart_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Log a weight in at least 2 sessions to see your progress chart.',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'} · latest first',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  /// One training of this exercise. Swipe a set to delete it, or delete the
  /// whole session from the menu.
  Widget _buildSessionCard(TrainingSession session, Set<int> recordIds) {
    final theme = Theme.of(context);
    final volume = totalVolume(session.logs);
    final isRecord = session.logs.any((log) => recordIds.contains(log.id));
    var number = 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDay(session.day),
                          style: theme.textTheme.titleMedium,
                        ),
                        if (session.workoutName case final workoutName?)
                          Text(workoutName, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (isRecord) const _RecordChip(),
                  PopupMenuButton<String>(
                    tooltip: 'Session options',
                    onSelected: (_) => _deleteSession(session),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete session'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            for (final log in session.logs)
              Dismissible(
                key: ValueKey(log.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _deleteLog(log),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: theme.colorScheme.errorContainer,
                  child: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          log.isWarmup ? 'W' : '${++number}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: log.isWarmup
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        _formatSet(log),
                        style: log.isWarmup
                            ? TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            if (volume > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  'Volume ${formatVolume(volume)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        actions: [
          if (_hasLogs)
            PopupMenuButton<_LogsAction>(
              onSelected: (action) => switch (action) {
                _LogsAction.move => _moveLogs(),
                _LogsAction.deleteAll => _deleteAllLogs(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _LogsAction.move,
                  child: Text('Move logs to…'),
                ),
                PopupMenuItem(
                  value: _LogsAction.deleteAll,
                  child: Text('Delete all logs'),
                ),
              ],
            ),
        ],
      ),
      body: FutureBuilder<List<ExerciseLogEntry>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildStatusState(
              icon: Icons.error_outline,
              title: 'Unable to load history',
              message: 'Try again in a moment.',
              action: OutlinedButton(
                onPressed: _refreshLogs,
                child: const Text('Retry'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildStatusState(
              icon: Icons.history,
              title: 'Loading history',
              message: 'Fetching saved sets from SQLite.',
            );
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshLogs,
              child: _buildStatusState(
                icon: Icons.history_toggle_off,
                title: 'No history yet',
                message: 'Save a set from a workout to see it here.',
              ),
            );
          }

          final recordIds = personalRecordIds(logs);
          final sessions = groupSessions(logs);

          return RefreshIndicator(
            onRefresh: _refreshLogs,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: sessions.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildSummary(logs, sessions.length, recordIds);
                }

                return _buildSessionCard(sessions[index - 1], recordIds);
              },
            ),
          );
        },
      ),
    );
  }
}

class _RecordChip extends StatelessWidget {
  const _RecordChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordColor = ChartColors.record(theme.brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: recordColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 14, color: recordColor),
          const SizedBox(width: 4),
          Text('PR', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
