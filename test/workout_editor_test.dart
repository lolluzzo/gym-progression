import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/screens/workout_editor_screen.dart';

Workout workout() => Workout(
      id: 'w1',
      name: 'Full body',
      updatedAt: DateTime(2026, 10, 13),
      exercises: [
        ExerciseEntry(id: 'e1', name: 'Bench', weight: '80', reps: '8'),
        ExerciseEntry(id: 'e2', name: 'Squat', weight: '100', reps: '5'),
        ExerciseEntry(
          id: 'e3',
          name: 'Row',
          weight: '60',
          reps: '10',
          alternatives: ['Cable row'],
          chosenName: 'Cable row',
        ),
      ],
    );

/// Opens the editor on [workout] and returns a getter for what it saves.
Future<Workout? Function()> openEditor(WidgetTester tester) async {
  Workout? saved;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          saved = await Navigator.of(context).push<Workout>(MaterialPageRoute(
            builder: (_) => WorkoutEditorScreen(workout: workout()),
          ));
        },
        child: const Text('go'),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
  return () => saved;
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.save));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('removing an exercise keeps the next one\'s id and values',
      (tester) async {
    final saved = await openEditor(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();
    await save(tester);

    final exercises = saved()!.exercises;
    expect(exercises.map((e) => e.id), ['e1', 'e3']);
    expect(exercises.map((e) => e.name), ['Bench', 'Row']);
    expect(exercises[1].weight, '60');
    expect(exercises[1].reps, '10');
    expect(exercises[1].activeName, 'Cable row');
  });

  testWidgets('a new exercise gets a new id and no values', (tester) async {
    final saved = await openEditor(tester);

    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Curl');
    await save(tester);

    final exercises = saved()!.exercises;
    expect(exercises.map((e) => e.name), ['Bench', 'Squat', 'Row', 'Curl']);
    expect(exercises.last.id, isNot(anyOf('e1', 'e2', 'e3')));
    expect(exercises.last.weight, '');
    expect(exercises[2].weight, '60');
  });
}
