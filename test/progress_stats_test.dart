import 'package:flutter_test/flutter_test.dart';
import 'package:gym_progression/models/achievement.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
import 'package:gym_progression/utils/week.dart';

ExerciseLogEntry log(
  int id,
  String exercise,
  String loggedAt, {
  String? weight,
  String? reps,
}) {
  return ExerciseLogEntry(
    id: id,
    exerciseName: exercise,
    loggedAt: DateTime.parse(loggedAt),
    weight: weight,
    reps: reps,
  );
}

ProfileStats stats({
  int totalCompleted = 0,
  int bestStreak = 0,
  int personalRecords = 0,
  double totalVolumeKg = 0,
}) {
  return ProfileStats(
    totalCompleted: totalCompleted,
    currentStreak: 0,
    bestStreak: bestStreak,
    personalRecords: personalRecords,
    totalVolumeKg: totalVolumeKg,
    plannedThisWeek: 0,
    completedThisWeek: 0,
  );
}

void main() {
  group('weekKeyFor', () {
    test('maps every day to its Monday', () {
      expect(weekKeyFor(DateTime(2026, 10, 5)), '2026-10-05');
      expect(weekKeyFor(DateTime(2026, 10, 11, 23, 59)), '2026-10-05');
      expect(weekKeyFor(DateTime(2026, 1, 1)), '2025-12-29');
    });

    test('round-trips through mondayFromWeekKey', () {
      expect(mondayFromWeekKey('2026-03-30'), DateTime(2026, 3, 30));
    });
  });

  group('parseMetric', () {
    test('reads plain, decimal and comma values', () {
      expect(parseMetric('100'), 100);
      expect(parseMetric('82.5'), 82.5);
      expect(parseMetric('82,5 kg'), 82.5);
      expect(parseMetric(' 60kg'), 60);
    });

    test('returns null without a number', () {
      expect(parseMetric(null), isNull);
      expect(parseMetric(''), isNull);
      expect(parseMetric('heavy'), isNull);
    });
  });

  group('personalRecordIds', () {
    test('first log is the baseline, only strictly heavier logs are PRs', () {
      final logs = [
        log(1, 'Squat', '2026-09-01T10:00:00', weight: '100'),
        log(2, 'Squat', '2026-09-08T10:00:00', weight: '100'),
        log(3, 'Squat', '2026-09-15T10:00:00', weight: '105'),
        log(4, 'Squat', '2026-09-22T10:00:00', weight: '102.5'),
        log(5, 'Squat', '2026-09-29T10:00:00', weight: '107,5'),
      ];

      expect(personalRecordIds(logs), {3, 5});
    });

    test('tracks each exercise separately, in any input order', () {
      final logs = [
        log(4, 'Bench', '2026-09-08T10:00:00', weight: '70'),
        log(3, 'Squat', '2026-09-08T10:00:00', weight: '90'),
        log(2, 'Bench', '2026-09-01T10:00:00', weight: '60'),
        log(1, 'Squat', '2026-09-01T10:00:00', weight: '100'),
      ];

      expect(personalRecordIds(logs), {4});
    });

    test('skips logs without a numeric weight', () {
      final logs = [
        log(1, 'Pull-up', '2026-09-01T10:00:00', weight: 'bodyweight'),
        log(2, 'Pull-up', '2026-09-08T10:00:00', weight: '10'),
        log(3, 'Pull-up', '2026-09-15T10:00:00'),
        log(4, 'Pull-up', '2026-09-22T10:00:00', weight: '12'),
      ];

      expect(personalRecordIds(logs), {4});
    });
  });

  group('volume and formatting', () {
    test('sums weight x reps where both are numbers', () {
      final logs = [
        log(1, 'Squat', '2026-09-01T10:00:00', weight: '100', reps: '5'),
        log(2, 'Bench', '2026-09-01T10:00:00', weight: '50', reps: '10'),
        log(3, 'Plank', '2026-09-01T10:00:00', reps: '3'),
      ];

      expect(totalVolume(logs), 1000);
      expect(bestWeight(logs), 100);
      expect(bestWeight([]), isNull);
    });

    test('formats kilograms and tonnes', () {
      expect(formatNumber(100), '100');
      expect(formatNumber(102.5), '102.5');
      expect(formatVolume(850), '850 kg');
      expect(formatVolume(12400), '12.4 t');
    });
  });

  group('currentWeekStreak', () {
    final wednesday = DateTime(2026, 10, 7);

    test('counts consecutive weeks up to the current one', () {
      expect(
        currentWeekStreak(
          ['2026-10-05', '2026-09-28', '2026-09-21', '2026-09-07'],
          wednesday,
        ),
        3,
      );
    });

    test('an empty current week does not break the streak yet', () {
      expect(currentWeekStreak(['2026-09-28', '2026-09-21'], wednesday), 2);
    });

    test('a missed full week resets it', () {
      expect(currentWeekStreak(['2026-09-21', '2026-09-14'], wednesday), 0);
      expect(currentWeekStreak([], wednesday), 0);
    });

    test('ignores duplicate weeks', () {
      expect(currentWeekStreak(['2026-10-05', '2026-10-05'], wednesday), 1);
    });
  });

  group('longestWeekStreak', () {
    test('finds the longest run', () {
      expect(
        longestWeekStreak([
          '2026-01-05',
          '2026-01-12',
          '2026-01-26',
          '2026-02-02',
          '2026-02-09',
        ]),
        3,
      );
    });

    test('runs across year ends and daylight saving changes', () {
      expect(longestWeekStreak(['2025-12-29', '2026-01-05']), 2);
      expect(longestWeekStreak(['2026-03-23', '2026-03-30', '2026-10-26']), 2);
    });

    test('is 0 without completions', () {
      expect(longestWeekStreak([]), 0);
    });
  });

  group('achievements', () {
    final firstStep = achievements.first;
    final tenTonnes =
        achievements.firstWhere((a) => a.title == '10 tonne club');

    test('report progress and unlock at the target', () {
      expect(firstStep.isUnlockedBy(stats()), isFalse);
      expect(firstStep.isUnlockedBy(stats(totalCompleted: 1)), isTrue);
      expect(tenTonnes.progressFor(stats(totalVolumeKg: 2500)), 0.25);
      expect(
        tenTonnes.progressLabel(stats(totalVolumeKg: 2500)),
        '2.5 t / 10.0 t',
      );
    });

    test('newlyUnlocked lists only what changed', () {
      final unlocked = newlyUnlocked(
        stats(totalCompleted: 9, personalRecords: 1),
        stats(totalCompleted: 10, personalRecords: 1),
      );

      expect(unlocked.map((a) => a.title), ['Getting serious']);
    });
  });
}
