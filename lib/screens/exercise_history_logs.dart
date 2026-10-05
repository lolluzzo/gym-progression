import 'package:flutter/material.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
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

class _ExerciseHistoryLogsScreenState extends State<ExerciseHistoryLogsScreen> {
  late Future<List<ExerciseLogEntry>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _loadLogs();
  }

  Future<List<ExerciseLogEntry>> _loadLogs() {
    return ExerciseLogStorage.getLogsForExercise(
      widget.profileId,
      widget.exerciseName,
    );
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _logsFuture = _loadLogs();
    });

    await _logsFuture;
  }

  Future<void> _deleteLog(ExerciseLogEntry entry) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete log?',
      message:
          'The log from ${_formatLoggedAt(entry.loggedAt)} will be removed.',
    );
    if (!confirmed) {
      return;
    }

    try {
      await ExerciseLogStorage.deleteLog(entry.id);
      if (!mounted) {
        return;
      }

      await _refreshLogs();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete the log.')),
      );
    }
  }

  String _formatMetric(String? value, {String suffix = ''}) {
    if (value == null || value.trim().isEmpty) {
      return 'Not set';
    }

    final formatted = value.trim();
    if (formatted.endsWith('.0')) {
      final withoutDecimals = formatted.substring(0, formatted.length - 2);
      return suffix.isEmpty ? withoutDecimals : '$withoutDecimals $suffix';
    }

    return suffix.isEmpty ? formatted : '$formatted $suffix';
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

  /// Best / latest / PR tiles and the weight chart, above the log list.
  Widget _buildSummary(List<ExerciseLogEntry> logs, Set<int> recordIds) {
    final theme = Theme.of(context);
    // Logs arrive latest first; the chart reads oldest first.
    final weightedLogs = logs.reversed
        .where((log) => parseMetric(log.weight) != null)
        .toList();
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
                          'Save at least 2 logs with a weight to see your progress chart.',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${logs.length} saved ${logs.length == 1 ? 'entry' : 'entries'} · latest first',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildEntryCard({
    required ExerciseLogEntry entry,
    required int index,
    required bool isRecord,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Log #${index + 1}',
                  style: theme.textTheme.titleMedium,
                ),
                if (isRecord) ...[
                  const SizedBox(width: 8),
                  const _RecordChip(),
                ],
                const Spacer(),
                Text(
                  _formatLoggedAt(entry.loggedAt),
                  style: theme.textTheme.bodySmall,
                ),
                IconButton(
                  onPressed: () => _deleteLog(entry),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete log',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Weight',
                    value: _formatMetric(entry.weight, suffix: 'kg'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Reps',
                    value: _formatMetric(entry.reps),
                  ),
                ),
              ],
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
                message:
                    'Save a log from the workout detail screen to see it here.',
              ),
            );
          }

          final recordIds = personalRecordIds(logs);

          return RefreshIndicator(
            onRefresh: _refreshLogs,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: logs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildSummary(logs, recordIds);
                }

                final entry = logs[index - 1];
                return _buildEntryCard(
                  entry: entry,
                  index: index - 1,
                  isRecord: recordIds.contains(entry.id),
                );
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
