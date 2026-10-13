import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/screens/workout_detail_screen.dart';
import 'package:gym_progression/services/app_database.dart';
import 'package:gym_progression/services/app_settings.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/widgets/set_row.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const profileId = 'detail';

Workout workout() => Workout(
      id: 'w1',
      name: 'Push A',
      updatedAt: DateTime.now(),
      exercises: [ExerciseEntry(id: 'e1', name: 'Bench press')],
    );

Widget screen() {
  return WorkoutDetailScreen(
    key: UniqueKey(),
    workout: workout(),
    profileId: profileId,
  );
}

Future<void> setGuideSeen(bool seen) async {
  SharedPreferences.setMockInitialValues({'sets_guide_seen': seen});
  await AppSettings.instance.load();
}

/// The database is real, so loads and saves run outside the fake clock.
Future<void> openScreen(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(home: screen()));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

Future<void> type(WidgetTester tester, int row, int column, String text) async {
  await tester.enterText(find.byType(TextField).at(row * 2 + column), text);
  await tester.pump();
}

Future<List<ExerciseLogEntry>> savedLogs(WidgetTester tester) async {
  final logs = await tester.runAsync(
    () => ExerciseLogStorage.getLogsForProfile(profileId),
  );
  return logs!;
}

List<String> badges(WidgetTester tester) {
  return tester
      .widgetList<SetBadge>(find.byType(SetBadge))
      .map((badge) => badge.label)
      .toList();
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    await databaseFactory.setDatabasesPath(
      Directory.systemTemp.createTempSync('gym_progression_detail').path,
    );
  });

  setUp(() async {
    await setGuideSeen(true);
    await ExerciseLogStorage.deleteLogsForProfile(profileId);
  });

  testWidgets('filling a row adds the next one, and saving twice keeps one log',
      (tester) async {
    await openScreen(tester);
    expect(badges(tester), ['1']);

    await type(tester, 0, 0, '80');
    expect(badges(tester), ['1', '2']);

    await type(tester, 0, 1, '8');
    await tapAndWait(tester, find.text('Save 1 set'));
    final first = await savedLogs(tester);
    expect(first.map((log) => (log.weight, log.reps)), [('80', '8')]);
    expect(find.text('Saved'), findsOneWidget);

    await type(tester, 0, 1, '9');
    await tapAndWait(tester, find.text('Save 1 set'));
    final second = await savedLogs(tester);
    expect(second.map((log) => (log.id, log.reps)), [(first.single.id, '9')]);
  });

  testWidgets('hints are never saved: a row with only a weight has no reps',
      (tester) async {
    await tester.runAsync(() async {
      final db = await AppDatabase.open();
      await db.insert(AppDatabase.logsTable, {
        'profile_id': profileId,
        'exercise_name': 'Bench press',
        'weight': '75',
        'reps': '8',
        'logged_at': DateTime.now()
            .subtract(const Duration(days: 7))
            .toIso8601String(),
        'workout_id': 'w1',
      });
      await db.close();
    });
    await openScreen(tester);
    expect(find.textContaining('Last time'), findsOneWidget);
    final reps = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(reps.decoration!.hintText, '8');

    await type(tester, 0, 0, '80');
    await tapAndWait(tester, find.text('Save 1 set'));

    final today = (await savedLogs(tester)).last;
    expect((today.weight, today.reps), ('80', null));
  });

  testWidgets('tapping a set number marks a warm-up and renumbers the sets',
      (tester) async {
    await openScreen(tester);
    await type(tester, 0, 0, '60');
    await type(tester, 1, 0, '80');
    expect(badges(tester), ['1', '2', '3']);

    await tester.tap(find.byType(SetBadge).first);
    await tester.pump();
    expect(badges(tester), ['W', '1', '2']);

    await tapAndWait(tester, find.text('Save 2 sets'));
    final logs = await savedLogs(tester);
    expect(logs.map((log) => log.isWarmup), [true, false]);
  });

  testWidgets('reopening the workout shows today\'s saved sets',
      (tester) async {
    await tester.runAsync(
      () => ExerciseLogStorage.saveSets(
        profileId: profileId,
        exerciseName: 'Bench press',
        sets: const [SetToSave(weight: '80', reps: '8')],
        workoutId: 'w1',
      ),
    );
    await openScreen(tester);

    final weight = tester.widget<TextField>(find.byType(TextField).first);
    expect(weight.controller!.text, '80');
    expect(badges(tester), ['1', '2']);
    expect(
      tester.widget<SetBadge>(find.byType(SetBadge).first).state,
      SetRowState.saved,
    );
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('going back with unsaved sets asks before dropping them',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<Workout>(builder: (_) => screen()),
            ),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await type(tester, 0, 0, '80');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved sets?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutDetailScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutDetailScreen), findsNothing);
    expect(await savedLogs(tester), isEmpty);
  });

  testWidgets('the guide opens the first time, and again from ?',
      (tester) async {
    await setGuideSeen(false);
    await openScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('Log a set'), findsOneWidget);
    expect(AppSettings.instance.setsGuideSeen, isTrue);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Grey numbers are hints'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Grey numbers are hints'), findsNothing);

    await openScreen(tester);
    await tester.pumpAndSettle();
    expect(find.text('Log a set'), findsNothing);

    await tester.tap(find.byTooltip('How to log sets'));
    await tester.pumpAndSettle();
    expect(find.text('Log a set'), findsOneWidget);
  });
}
