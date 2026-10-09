import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/screens/history_screen.dart';
import 'package:gym_progression/screens/import_workouts_screen.dart';
import 'package:gym_progression/screens/workout_detail_screen.dart';
import 'package:gym_progression/screens/workout_editor_screen.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final dbDir = Directory.systemTemp.createTempSync('gym_progression_smoke').path;

Workout workout() => Workout(
      id: 'w1',
      name: 'Push',
      updatedAt: DateTime.now(),
      exercises: [
        ExerciseEntry(id: 'e1', name: 'Bench press', alternatives: ['Dumbbell press', 'Machine press']),
        ExerciseEntry(id: 'e2', name: 'Dips'),
      ],
    );

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await databaseFactory.setDatabasesPath(dbDir);
  });

  testWidgets('import screen previews and pops workouts', (tester) async {
    List<Workout>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.of(context).push<List<Workout>>(MaterialPageRoute(
              builder: (_) => const ImportWorkoutsScreen(initialText: 'Program\nPush\n  - Bench\n  - Dips\nPull\n- Row'),
            ));
          },
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('1. Bench'), findsOneWidget);
    await tester.tap(find.text('Import 2 workouts'));
    await tester.pumpAndSettle();
    expect(result!.map((w) => w.name), ['Push', 'Pull']);
    expect(result!.first.exercises.map((e) => e.name), ['Bench', 'Dips']);
    expect(result!.first.updatedAt.isAfter(result!.last.updatedAt), isTrue);
  });

  testWidgets('editor shows, adds and removes alternatives', (tester) async {
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
    expect(find.byType(InputChip), findsNWidgets(2));
    await tester.tap(find.byType(ActionChip).last);
    await tester.pumpAndSettle();
    expect(find.text('Alternative to Dips'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Bench dips');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.clear).first); // delete 'Dumbbell press'
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(saved!.exercises[0].alternatives, ['Machine press']);
    expect(saved!.exercises[1].alternatives, ['Bench dips']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail screen switches form and logs under it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    Workout? popped;
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Workout>(MaterialPageRoute(
                builder: (_) => WorkoutDetailScreen(workout: workout(), profileId: 'smoke'),
              ));
            },
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Dumbbell press'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Dumbbell press'));
    await tester.pump();
    expect(find.text('Dumbbell press'), findsNWidgets(2)); // title + chip
    await tester.enterText(find.byType(TextField).at(0), '30');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save log').first);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(const Duration(seconds: 3));
    if (find.byType(Dialog).evaluate().isNotEmpty) {
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.byType(FilledButton)));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final logs = await tester.runAsync(() => ExerciseLogStorage.getLogsForProfile('smoke'));
    expect(logs!.single.exerciseName, 'Dumbbell press');
    expect(logs.single.workoutId, 'w1');
    expect(logs.single.workoutName, 'Push');
    await tester.tap(find.text('Save progress'));
    await tester.pumpAndSettle();
    expect(popped!.exercises.first.activeName, 'Dumbbell press');
  });

  testWidgets('history view lists the session', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: HistoryView(profileId: 'smoke'))));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    // ignore: avoid_print
    print(find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Push'), findsOneWidget);
    expect(find.textContaining('1 exercise'), findsOneWidget);
    await tester.tap(find.text('Push'));
    await tester.pumpAndSettle();
    expect(find.text('Dumbbell press'), findsOneWidget);
    expect(find.text('30 kg × 10 reps'), findsOneWidget);
    await tester.runAsync(() => ExerciseLogStorage.deleteLogsForProfile('smoke'));
  });
}
