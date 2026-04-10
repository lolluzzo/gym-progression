import 'package:flutter/material.dart';
import 'package:gym_progression/models/workout.dart';

class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({super.key, this.workout});

  final Workout? workout;

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<TextEditingController> _exerciseControllers = [];

  bool get _isEditing => widget.workout != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.workout?.name ?? '';

    final exercises = widget.workout?.exercises ?? [];
    if (exercises.isEmpty) {
      _addExerciseField();
    } else {
      for (final exercise in exercises) {
        _exerciseControllers.add(TextEditingController(text: exercise.name));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _exerciseControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addExerciseField() {
    setState(() {
      _exerciseControllers.add(TextEditingController());
    });
  }

  void _removeExerciseField(int index) {
    if (_exerciseControllers.length == 1) {
      return;
    }

    setState(() {
      final controller = _exerciseControllers.removeAt(index);
      controller.dispose();
    });
  }

  void _saveWorkout() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final exerciseNames = _exerciseControllers
        .map((controller) => controller.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (exerciseNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise.')),
      );
      return;
    }

    final previousExercises = widget.workout?.exercises ?? [];
    final exercises = exerciseNames.asMap().entries.map((entry) {
      final existingExercise = entry.key < previousExercises.length
          ? previousExercises[entry.key]
          : null;

      return ExerciseEntry(
        id: existingExercise?.id ??
            '${DateTime.now().microsecondsSinceEpoch}_${entry.key}',
        name: entry.value,
        weight: existingExercise?.weight ?? '',
        reps: existingExercise?.reps ?? '',
      );
    }).toList();

    final workout = Workout(
      id: widget.workout?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      exercises: exercises,
      updatedAt: DateTime.now(),
      lastCompletedWeekKey: widget.workout?.lastCompletedWeekKey,
    );

    Navigator.of(context).pop(workout);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Workout' : 'New Workout'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveWorkout,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Workout name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a workout name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exercises',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: _addExerciseField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add exercise'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _exerciseControllers.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _exerciseControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Exercise ${i + 1}',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter an exercise name.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeExerciseField(i),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
