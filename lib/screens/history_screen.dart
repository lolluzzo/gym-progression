import 'package:flutter/material.dart';
import 'package:gym_progression/screens/exercise_history_logs.dart';
import 'package:gym_progression/services/exercise_links.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
import 'package:gym_progression/services/training_sessions.dart';
import 'package:gym_progression/services/workout_storage.dart';
import 'package:gym_progression/widgets/set_row.dart';

typedef _History = ({
  List<TrainingSession> sessions,
  Map<String, List<ExerciseLogEntry>> unlinked,
});

/// Past trainings, latest first. Each one lists what was logged for every
/// exercise. Shown as a tab of the home screen.
class HistoryView extends StatefulWidget {
  const HistoryView({super.key, required this.profileId});

  final String profileId;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  late Future<_History> _historyFuture = _loadHistory();

  Future<_History> _loadHistory() async {
    final logs = await ExerciseLogStorage.getLogsForProfile(widget.profileId);
    final workouts = await WorkoutStorage.loadWorkouts(widget.profileId);
    return (
      sessions: groupSessions(logs),
      unlinked: unlinkedExercises(logs, workouts),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = _loadHistory();
    });

    await _historyFuture;
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
    // Logs may have been deleted or moved there.
    if (mounted) {
      await _refresh();
    }
  }

  String _formatDay(DateTime day) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(day.day)}/${twoDigits(day.month)}/${day.year}';
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

  /// Lists the exercises with unlinked logs. Their history screen can move
  /// or delete the logs.
  Future<void> _reviewUnlinked(
    Map<String, List<ExerciseLogEntry>> unlinked,
  ) async {
    final exerciseName = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Open an exercise to move its logs to one in your workouts, or to delete them.',
            ),
          ),
          for (final MapEntry(key: name, value: logs) in unlinked.entries)
            ListTile(
              title: Text(name),
              subtitle: Text(
                '${logs.length == 1 ? '1 log' : '${logs.length} logs'} · last ${_formatDay(logs.last.loggedAt.toLocal())}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pop(name),
            ),
        ],
      ),
    );

    if (exerciseName != null && mounted) {
      await _openExerciseHistory(exerciseName);
    }
  }

  Widget _buildUnlinkedCard(Map<String, List<ExerciseLogEntry>> unlinked) {
    final count = unlinked.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded),
        title: Text(
          count == 1
              ? "1 exercise has logs but isn't in any workout"
              : "$count exercises have logs but aren't in any workout",
        ),
        trailing: TextButton(
          onPressed: () => _reviewUnlinked(unlinked),
          child: const Text('Review'),
        ),
      ),
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
              subtitle: Text.rich(setsLineSpan(context, logs)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openExerciseHistory(exerciseName),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_History>(
      future: _historyFuture,
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

        final sessions = snapshot.data?.sessions ?? [];
        final unlinked = snapshot.data?.unlinked ?? {};

        return RefreshIndicator(
          onRefresh: _refresh,
          child: sessions.isEmpty
              ? _buildMessage(
                  Icons.history_toggle_off,
                  'No trainings yet',
                  'Save a set during a workout to see it here.',
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (unlinked.isNotEmpty) _buildUnlinkedCard(unlinked),
                    for (final session in sessions) _buildSession(session)
                  ],
                ),
        );
      },
    );
  }
}
