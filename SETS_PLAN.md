# Plan: sets (series)

Status as of 2026-10-07: plan only.

## 1. The concept

In a session, an exercise is a list of **sets**. Each set has a weight and a number of reps. Three or four sets is typical, and the weight often changes between them: ramping up (60 → 70 → 80) or dropping down.

There are two layers:

- **Plan**, in the workout template: how many sets, and the target reps.
- **Performed**, in the logs: what you actually lifted today, set by set.

## 2. Where the app is today

- `ExerciseEntry` holds one `weight` and one `reps`: the last values typed into the template.
- Each **Save log** inserts one row in `workout_logs`. Saving three times already records three sets, but without a set number, and the UI makes it awkward.
- The new History tab groups logs by workout and day, so it already shows one line per set.

The storage is mostly there. Sets are mainly a UI change plus a small schema change.

## 3. Data model

### Template (SharedPreferences JSON)

```dart
class ExerciseEntry {
  // ...existing fields
  final int plannedSets;     // default 3
  final String targetReps;   // optional: "8", "8-10"
}
```

- **Prefill the weights from the last session of the chosen form, not from the template.** This solves two problems:
  - Alternatives: the bench press and the dumbbell press need different weights, and each form has its own logs.
  - Duplicated data: the template no longer stores weights.
- `weight`/`reps` stay readable for old data. They become the fallback prefill when a form has no logs yet.
- Check: a unit test that old JSON loads with `plannedSets: 3`.

### Logs (DB v4)

| Column | Meaning |
| --- | --- |
| `set_index INTEGER` | 1-based. NULL for older logs, which count as one set each. |
| `session_id TEXT` | Created when you open a workout. It groups sets exactly, even with two sessions in one day or one that crosses midnight. History uses it when present and falls back to workout + day, the current logic. |

Later: `is_warmup INTEGER`, so warm-up sets stay out of PRs and volume.

Check: an upgrade test from a v3 database that has data in it, the same kind of test used for v2 → v3 in this change.

## 4. UI

### Workout screen, per exercise card

```
Bench press                         Best 85 kg
[Bench press] [Dumbbell press] [Machine]     ← existing form picker
Set   kg     reps
1     80     8      ✓
2     85     6      ✓
3     85     5      ○
+ Add set
Last time: 80×8 · 85×6 · 85×5
```

- **Ticking ✓ saves that set as a log right away**, so nothing is lost if the app is killed. Unticking deletes that row. This replaces the per-exercise **Save log** button.
- A new set copies the previous row's values, since most sets repeat the weight.
- The PR celebration fires on the ticked set. The existing per-row logic works unchanged.
- Later: the rest timer from the MVP spec starts when a set is ticked.
- **Complete workout** keeps working as it does today: it marks the week as done.

### Editor

- Each exercise gets a sets stepper (`– 3 +`) and an optional reps field (`8-10`).

### Import

- Read `Bench press 4x8`, `4 x 8` and `4×8` at the end of a line: name `Bench press`, 4 planned sets, target reps 8.
- Regex: `(\d+)\s*[x×]\s*(\d+(?:-\d+)?)\s*$`. Add parser tests next to the existing ones.

### History and stats

- Each exercise in a session shows its sets: `80×8 · 85×6 · 85×5`.
- **Chart:** one point per session, the top set (heaviest weight). Today it plots one point per log, which would put three points on each day.
- **Volume:** unchanged (the sum of weight × reps over the rows). It becomes correct without any work.
- **PRs:** unchanged (heaviest weight per row). Later, use an estimated 1RM (Epley: `w × (1 + reps / 30)`) so that 80×10 beats 85×2.

## 5. Steps

1. Model: `plannedSets`/`targetReps` and the JSON fallback. Check: unit tests on old and new JSON.
2. DB v4: `set_index` and `session_id`. Check: the upgrade test from v3.
3. Workout screen: set rows, tick-to-log, prefill from the last session. Check: a widget test, then a real session on the phone.
4. History grouping by `session_id` with the fallback, and the top-set chart. Check: unit tests for `groupSessions` and for the chart aggregation.
5. Editor stepper and `4x8` import. Check: parser tests.

## 6. Decisions for you

- Log each set when it's ticked (recommended), or all sets at the end?
- Warm-up sets: track them and leave them out of PRs, or don't track them at all?
- Can the plan give each set different reps (a 12/10/8 pyramid), or is there one target for all sets?
