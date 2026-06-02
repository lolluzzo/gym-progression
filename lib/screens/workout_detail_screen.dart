import 'package:flutter/material.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/screens/exercise_history_logs.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({super.key, required this.workout});

  final Workout workout;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Workout _workout;
  late final Map<String, TextEditingController> _weightControllers;
  late final Map<String, TextEditingController> _repsControllers;

  String get _currentWeekKey => _weekKeyFor(DateTime.now());

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

  String _weekKeyFor(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    final weekdayOffset = localDate.weekday - DateTime.monday;
    final monday = localDate.subtract(Duration(days: weekdayOffset));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  Future<void> _saveExerciseLog(ExerciseEntry exercise) async {
    try {
      await ExerciseLogStorage.saveLog(
        exerciseName: exercise.name,
        weight: _weightControllers[exercise.id]?.text,
        reps: _repsControllers[exercise.id]?.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved log for ${exercise.name}.')),
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
          exerciseName: exercise.name,
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
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
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
