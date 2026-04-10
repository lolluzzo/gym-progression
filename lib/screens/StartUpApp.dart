import 'package:flutter/material.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/screens/workout_detail_screen.dart';
import 'package:gym_progression/screens/workout_editor_screen.dart';
import 'package:gym_progression/services/workout_storage.dart';

class StartUpApp extends StatefulWidget {
  const StartUpApp({super.key});

  @override
  State<StartUpApp> createState() => _StartUpAppState();
}

class _StartUpAppState extends State<StartUpApp> {
  bool _isLoading = false;
  List<Workout> _workouts = [];

  String get _currentWeekKey => _weekKeyFor(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() => _isLoading = true);

    try {
      final workouts = await WorkoutStorage.loadWorkouts();
      final normalizedWorkouts =
          workouts.map(_normalizeWorkoutForCurrentWeek).toList();
      if (!mounted) {
        return;
      }

      setState(() {
        _workouts = normalizedWorkouts;
        _isLoading = false;
      });

      await WorkoutStorage.saveWorkouts(normalizedWorkouts);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load workouts.')),
      );
    }
  }

  Future<void> _saveWorkouts(List<Workout> workouts) async {
    final sortedWorkouts = [...workouts]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    setState(() {
      _workouts = sortedWorkouts;
    });

    await WorkoutStorage.saveWorkouts(sortedWorkouts);
  }

  Workout _normalizeWorkoutForCurrentWeek(Workout workout) {
    if (workout.lastCompletedWeekKey == null) {
      return workout;
    }

    if (workout.lastCompletedWeekKey == _currentWeekKey) {
      return workout;
    }

    return workout.copyWith(clearCompletedWeek: true);
  }

  bool _isCompletedThisWeek(Workout workout) {
    return workout.lastCompletedWeekKey == _currentWeekKey;
  }

  Future<void> _openNewWorkout() async {
    final workout = await Navigator.of(context).push<Workout>(
      MaterialPageRoute(
        builder: (_) => const WorkoutEditorScreen(),
      ),
    );

    if (workout == null) {
      return;
    }

    await _saveWorkouts([..._workouts, workout]);
  }

  Future<void> _editWorkout(Workout workout) async {
    final updatedWorkout = await Navigator.of(context).push<Workout>(
      MaterialPageRoute(
        builder: (_) => WorkoutEditorScreen(workout: workout),
      ),
    );

    if (updatedWorkout == null) {
      return;
    }

    final workouts = _workouts
        .map((item) => item.id == updatedWorkout.id ? updatedWorkout : item)
        .toList();

    await _saveWorkouts(workouts);
  }

  Future<void> _openWorkout(Workout workout) async {
    final updatedWorkout = await Navigator.of(context).push<Workout>(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(workout: workout),
      ),
    );

    if (updatedWorkout == null) {
      return;
    }

    final workouts = _workouts
        .map((item) => item.id == updatedWorkout.id ? updatedWorkout : item)
        .toList();

    await _saveWorkouts(workouts);
  }

  String _subtitleForWorkout(Workout workout) {
    final trackedExercises = workout.exercises.where(
      (exercise) => exercise.weight.isNotEmpty || exercise.reps.isNotEmpty,
    );

    final status = _isCompletedThisWeek(workout)
        ? 'Completed this week'
        : 'To complete this week';
    return '$status • ${workout.exercises.length} exercises • ${trackedExercises.length} updated';
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();
    return '$day/$month/$year';
  }

  String _weekKeyFor(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    final weekdayOffset = localDate.weekday - DateTime.monday;
    final monday = localDate.subtract(Duration(days: weekdayOffset));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Workouts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewWorkout,
        icon: const Icon(Icons.add),
        label: const Text('Add workout'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No workouts saved yet',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create a workout and add the exercises you want to track offline on this device.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _openNewWorkout,
                          icon: const Icon(Icons.add),
                          label: const Text('Create first workout'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadWorkouts,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _workouts.length,
                    itemBuilder: (context, index) {
                      final workout = _workouts[index];
                      final isCompleted = _isCompletedThisWeek(workout);
                      return Card(
                        color:
                            isCompleted ? Colors.green.withOpacity(0.12) : null,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: const CircleAvatar(
                            child: Icon(Icons.fitness_center),
                          ),
                          title: Text(workout.name),
                          subtitle: Text(
                            '${_subtitleForWorkout(workout)}\nUpdated ${_formatDate(workout.updatedAt)}',
                          ),
                          isThreeLine: true,
                          onTap: () => _openWorkout(workout),
                          trailing: IconButton(
                            onPressed: () => _editWorkout(workout),
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Edit workout',
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
