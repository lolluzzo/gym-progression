import 'package:flutter/material.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';

class ExerciseHistoryLogsScreen extends StatefulWidget {
  const ExerciseHistoryLogsScreen({super.key, required this.exerciseName});

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
    _logsFuture = ExerciseLogStorage.getLogsForExercise(widget.exerciseName);
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _logsFuture = ExerciseLogStorage.getLogsForExercise(widget.exerciseName);
    });

    await _logsFuture;
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

  Widget _buildEntryCard({
    required ExerciseLogEntry entry,
    required int index,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Log #${index + 1}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  _formatLoggedAt(entry.loggedAt),
                  style: theme.textTheme.bodySmall,
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

          return RefreshIndicator(
            onRefresh: _refreshLogs,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: logs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exercise history',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${logs.length} saved ${logs.length == 1 ? 'entry' : 'entries'}',
                          ),
                          const SizedBox(height: 4),
                          const Text('Sorted from latest to oldest.'),
                        ],
                      ),
                    ),
                  );
                }

                return _buildEntryCard(
                  entry: logs[index - 1],
                  index: index - 1,
                );
              },
            ),
          );
        },
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
