import 'package:flutter/material.dart';
import 'package:gym_progression/screens/exercise_history_logs.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
import 'package:gym_progression/services/training_sessions.dart';

/// Past trainings, latest first. Each one lists what was logged for every
/// exercise. Shown as a tab of the home screen.
class HistoryView extends StatefulWidget {
  const HistoryView({super.key, required this.profileId});

  final String profileId;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late Future<List<TrainingSession>> _sessionsFuture = _loadSessions();

  Future<List<TrainingSession>> _loadSessions() async {
    final logs = await ExerciseLogStorage.getLogsForProfile(widget.profileId);
    return groupSessions(logs);
  }

  Future<void> _refresh() async {
    setState(() {
      _sessionsFuture = _loadSessions();
    });

    await _sessionsFuture;
  }

  Future<void> _openExerciseHistory(String exerciseName) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseHistoryLogsScreen(
          profileId: widget.profileId,
          exerciseName: exerciseName,
        ),
      ),
    );
    // A log may have been deleted there.
    if (mounted) {
      await _refresh();
    }
  }

  String _formatDay(DateTime day) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(day.day)}/${twoDigits(day.month)}/${day.year}';
  }

  String _formatLog(ExerciseLogEntry log) {
    final weight = parseMetric(log.weight);
    final parts = [
      if (weight != null)
        '${formatNumber(weight)} kg'
      else if (log.weight != null)
        log.weight!,
      if (log.reps != null) '${log.reps} reps',
    ];

    return parts.isEmpty ? 'No values' : parts.join(' × ');
  }

  Widget _buildMessage(IconData icon, String title, String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildSession(TrainingSession session) {
    final logsByExercise = session.logsByExercise;
    final volume = totalVolume(session.logs);
    final summary = [
      _formatDay(session.day),
      logsByExercise.length == 1
          ? '1 exercise'
          : '${logsByExercise.length} exercises',
      if (volume > 0) formatVolume(volume),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const CircleAvatar(child: Icon(Icons.event_note)),
        title: Text(session.workoutName ?? 'Logged exercises'),
        subtitle: Text(summary),
        children: [
          for (final MapEntry(key: exerciseName, value: logs)
              in logsByExercise.entries)
            ListTile(
              title: Text(exerciseName),
              subtitle: Text(logs.map(_formatLog).join('\n')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openExerciseHistory(exerciseName),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrainingSession>>(
      future: _sessionsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _buildMessage(
              Icons.error_outline,
              'Unable to load history',
              'Pull down to try again.',
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sessions = snapshot.data ?? [];

        return RefreshIndicator(
          onRefresh: _refresh,
          child: sessions.isEmpty
              ? _buildMessage(
                  Icons.history_toggle_off,
                  'No trainings yet',
                  'Save a log for an exercise during a workout to see it here.',
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    for (final session in sessions) _buildSession(session)
                  ],
                ),
        );
      },
    );
  }
}
