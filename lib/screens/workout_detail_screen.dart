import 'package:flutter/material.dart';
import 'package:gym_progression/models/achievement.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/screens/exercise_history_logs.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
import 'package:gym_progression/utils/week.dart';
import 'package:gym_progression/widgets/celebration.dart';
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

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Workout _workout;
  late final Map<String, TextEditingController> _weightControllers;
  late final Map<String, TextEditingController> _repsControllers;
  Map<String, double> _bestWeights = {};

  String get _currentWeekKey => weekKeyFor(DateTime.now());

  bool get _isCompletedThisWeek =>
      _workout.lastCompletedWeekKey == _currentWeekKey;

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
    _weightControllers = {
      for (final exercise in _workout.exercises)
        exercise.id: TextEditingController(text: exercise.weight),
    };
    _repsControllers = {
      for (final exercise in _workout.exercises)
        exercise.id: TextEditingController(text: exercise.reps),
    };
    _loadBestWeights();
  }

  @override
  void dispose() {
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    for (final controller in _repsControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveWorkoutProgress() {
    final updatedExercises = _workout.exercises.map((exercise) {
      return exercise.copyWith(
        weight: _weightControllers[exercise.id]?.text.trim() ?? '',
        reps: _repsControllers[exercise.id]?.text.trim() ?? '',
      );
    }).toList();

    final updatedWorkout = _workout.copyWith(
      exercises: updatedExercises,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _workout = updatedWorkout;
    });

    Navigator.of(context).pop(updatedWorkout);
  }

  void _markWorkoutComplete() {
    final updatedExercises = _workout.exercises.map((exercise) {
      return exercise.copyWith(
        weight: _weightControllers[exercise.id]?.text.trim() ?? '',
        reps: _repsControllers[exercise.id]?.text.trim() ?? '',
      );
    }).toList();

    final updatedWorkout = _workout.copyWith(
      exercises: updatedExercises,
      updatedAt: DateTime.now(),
      lastCompletedWeekKey: _currentWeekKey,
    );

    setState(() {
      _workout = updatedWorkout;
    });

    Navigator.of(context).pop(updatedWorkout);
  }

  void _markWorkoutToDoAgain() {
    final updatedWorkout = _workout.copyWith(
      updatedAt: DateTime.now(),
      clearCompletedWeek: true,
    );

    setState(() {
      _workout = updatedWorkout;
    });

    Navigator.of(context).pop(updatedWorkout);
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

  Future<void> _loadBestWeights() async {
    final logs = await ExerciseLogStorage.getLogsForProfile(widget.profileId);
    final bestWeights = <String, double>{};
    for (final log in logs) {
      final weight = parseMetric(log.weight);
      final best = bestWeights[log.exerciseName];
      if (weight != null && (best == null || weight > best)) {
        bestWeights[log.exerciseName] = weight;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() => _bestWeights = bestWeights);
  }

  Future<void> _saveExerciseLog(ExerciseEntry exercise) async {
    final weightText = _weightControllers[exercise.id]?.text;
    final exerciseName = exercise.activeName;

    try {
      final previousBest = bestWeight(
        await ExerciseLogStorage.getLogsForExercise(
          widget.profileId,
          exerciseName,
        ),
      );
      final statsBefore = await ProfileStats.load(widget.profileId);

      await ExerciseLogStorage.saveLog(
        profileId: widget.profileId,
        exerciseName: exerciseName,
        weight: weightText,
        reps: _repsControllers[exercise.id]?.text,
        workoutId: _workout.id,
        workoutName: _workout.name,
      );

      final statsAfter = await ProfileStats.load(widget.profileId);
      final unlocked = newlyUnlocked(statsBefore, statsAfter);
      final weight = parseMetric(weightText);

      if (!mounted) {
        return;
      }

      if (weight != null && (previousBest == null || weight > previousBest)) {
        setState(() => _bestWeights[exerciseName] = weight);
      }

      if (previousBest != null && weight != null && weight > previousBest) {
        await showCelebration(
          context,
          icon: Icons.emoji_events_rounded,
          title: 'New personal record!',
          message:
              '$exerciseName: ${formatNumber(weight)} kg, up from ${formatNumber(previousBest)} kg.',
          unlocked: unlocked,
        );
        return;
      }

      if (unlocked.isNotEmpty) {
        await showCelebration(
          context,
          icon: unlocked.first.icon,
          title: 'Log saved',
          message: 'Saved log for $exerciseName.',
          unlocked: unlocked,
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved log for $exerciseName.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save the log.')),
      );
    }
  }

  void _openExerciseHistory(ExerciseEntry exercise) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseHistoryLogsScreen(
          profileId: widget.profileId,
          exerciseName: exercise.activeName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_workout.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Card(
            color: _isCompletedThisWeek ? Colors.green.withOpacity(0.12) : null,
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
                        : 'Save your values, then mark the workout as completed when you finish it.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _saveWorkoutProgress,
                        icon: const Icon(Icons.save),
                        label: const Text('Save progress'),
                      ),
                      if (!_isCompletedThisWeek)
                        FilledButton.tonalIcon(
                          onPressed: _markWorkoutComplete,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Complete workout'),
                        ),
                      if (_isCompletedThisWeek)
                        OutlinedButton.icon(
                          onPressed: _markWorkoutToDoAgain,
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
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.activeName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (_bestWeights[exercise.activeName] != null)
                          _BestWeightChip(
                            weight: _bestWeights[exercise.activeName]!,
                          ),
                      ],
                    ),
                    if (exercise.alternatives.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final form in exercise.forms)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(form),
                                  selected: form == exercise.activeName,
                                  onSelected: (_) =>
                                      _chooseForm(exercise, form),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _saveExerciseLog(exercise),
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Save log'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _openExerciseHistory(exercise),
                          icon: const Icon(Icons.history),
                          label: const Text('View history'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _weightControllers[exercise.id],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Weight',
                              hintText: 'kg',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _repsControllers[exercise.id],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Reps',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
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
