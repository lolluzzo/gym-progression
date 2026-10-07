import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/services/workout_import.dart';

/// Turns a pasted or shared note into workouts. Pops with the new workouts.
class ImportWorkoutsScreen extends StatefulWidget {
  const ImportWorkoutsScreen({super.key, this.initialText = ''});

  final String initialText;

  @override
  State<ImportWorkoutsScreen> createState() => _ImportWorkoutsScreenState();
}

class _ImportWorkoutsScreenState extends State<ImportWorkoutsScreen> {
  late final TextEditingController _textController =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (!mounted) {
      return;
    }

    if (text == null || text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The clipboard has no text.')),
      );
      return;
    }

    setState(() => _textController.text = text);
  }

  void _import(List<ImportedWorkout> importedWorkouts) {
    final now = DateTime.now();
    final workouts = [
      for (final (i, imported) in importedWorkouts.indexed)
        Workout(
          id: '${now.millisecondsSinceEpoch}_$i',
          name: imported.name,
          exercises: [
            for (final (j, name) in imported.exercises.indexed)
              ExerciseEntry(
                  id: '${now.microsecondsSinceEpoch}_${i}_$j', name: name),
          ],
          // The list shows the latest update first: a millisecond apart
          // keeps the workouts in the note's order.
          updatedAt: now.subtract(Duration(milliseconds: i)),
        ),
    ];

    Navigator.of(context).pop(workouts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final importedWorkouts = parseWorkoutNotes(_textController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Import workouts')),
      floatingActionButton: importedWorkouts.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _import(importedWorkouts),
              icon: const Icon(Icons.download_done),
              label: Text(
                importedWorkouts.length == 1
                    ? 'Import 1 workout'
                    : 'Import ${importedWorkouts.length} workouts',
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'Write each workout name on its own line, with its exercises as a list below it.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            minLines: 6,
            maxLines: 12,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Push day\n- Bench press\n- Shoulder press',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            importedWorkouts.isEmpty ? 'No workouts found yet' : 'Preview',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final workout in importedWorkouts)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(workout.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final (i, exercise) in workout.exercises.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${i + 1}. $exercise'),
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
