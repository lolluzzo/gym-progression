# Plan: logs lost after a rename, and old values after the weekly reset

Status as of 2026-10-13: implemented, except the manual checks on the phone.

## 1. Logs lost after renaming an exercise

### What happens

- Logs are linked to an exercise **by name only**. `workout_logs.exercise_name` has to equal the exercise's `activeName`, which is its name or the chosen alternative. Logs have no exercise id.
- The editor keeps the exercise's `id` when you rename it, but the logs keep the old name. So after a rename:
  - **View history** on the workout screen opens the new name and shows nothing.
  - The **Best** chip, the PR check and the chart start again from zero.
- The logs still exist. The **History** tab lists them under the old name, and tapping one opens its history. Nothing links them back to the workout, though.
- Removing an exercise or an alternative, or deleting a workout, has the same effect: the logs stay, under a name that nothing uses.

Linking by name is partly intentional: "Bench press" in two workouts shares one history. Any fix has to keep that.

### Bug found along the way: the editor matches exercises by position

`WorkoutEditorScreen._saveWorkout` takes `id`, `weight`, `reps` and `chosenName` from the exercise **at the same position** in the old list (`previousExercises[entry.key]`). If you remove the second of three exercises, the third one takes over the second one's id, values and chosen form.

This has to be fixed first. The rename detection below compares exercises by id. With shifted ids, removing Squat would make Row look like "Squat → Row", and the squat logs would be moved onto Row.

Fix: the editor keeps each row's id in a list next to `_exerciseControllers`, the same way it keeps `_alternatives`. New rows get a new id.
Check: a widget test that removes the middle exercise and expects the third one to keep its id and values.

### Options

| Option | What | Cost | Verdict |
| --- | --- | --- | --- |
| A. Move logs on rename | After the editor saves, find renamed exercises (same id, new name) and offer to move their logs to the new name | Small | Do it. It prevents new orphans. |
| B. Repair tools | "Move logs to…" and "Delete all logs" on an exercise's history, plus a list of names that have logs but aren't in any workout | Small to medium | Do it. A can't fix the orphans you already have. It also misses removed exercises, deleted workouts and renamed alternatives (an alternative is renamed by deleting its chip and adding a new one, so it can't be detected). |
| C. Link logs by a stable exercise id | An `exercises` table that workouts and logs point to by id | Large. It migrates both the SharedPreferences JSON and the DB, and needs a way to share one exercise across workouts. | Not now. Revisit if the exercise catalog from [AI_TRAINER_PLAN.md](AI_TRAINER_PLAN.md) gets built. |

Recommended: **A + B**.

### A. Move logs on rename

Where: in `StartUpApp._editWorkout`, after the editor closes. That code has the old workout, the new one, every other workout of the profile and the profile id, so the editor can stay a plain form.

1. For each exercise whose id is in both versions and whose name changed, count the logs under the old name.
2. Skip the exercise if it has no logs, or if any workout of the profile still uses the old name, as a name or as an alternative. Those logs aren't orphaned.
3. For the exercises left, show one dialog:

   ```
   Move logs to the new names?
   Panca → Bench press · 12 logs
   Lat machine → Lat pulldown · 4 logs
                        [Keep old names]  [Move logs]
   ```

   If the new name already has logs, the two histories merge. For the same exercise, that's the expected result.
4. **Move logs** runs `UPDATE workout_logs SET exercise_name = ? WHERE profile_id = ? AND exercise_name = ?`. PRs, volume and the chart are computed from the logs, so they update with no extra work.

- Storage: `ExerciseLogStorage.renameExercise(profileId, from, to)`, which returns the number of logs moved.
- Logic: a pure function `renamedExercises(Workout before, Workout after)` that returns `(from, to)` pairs.
- Checks:
  - Unit tests: a rename is detected. A removed or reordered exercise isn't a rename, and neither is an unchanged name.
  - A storage test with sqflite ffi, like the smoke test: only that profile's logs with that exact name are moved.

### B. Repair tools

1. **Exercise history screen** (`ExerciseHistoryLogsScreen`): a ⋮ menu in the app bar with two actions.
   - **Move logs to…** opens a sheet that lists every exercise and alternative in the profile's workouts, grouped by workout. Picking one runs `renameExercise` and closes the screen.
   - **Delete all logs** asks for confirmation, then runs `DELETE … WHERE profile_id = ? AND exercise_name = ?`.

   Both actions work for any name. You can also use them to merge two names you've used for the same exercise, like "Bench" and "Bench press".
2. **History tab**: when some names in the logs aren't used by any workout, a card appears at the top:

   ```
   ⚠ 2 exercises have logs but aren't in any workout     [Review]
   ```

   **Review** lists those names, for example `Panca · 12 logs · last 07/10`. Tapping a name opens its history screen, and the menu from step 1 does the rest.

- Storage: `deleteLogsForExercise(profileId, name)`.
- Logic: a pure function `unlinkedExerciseNames(List<ExerciseLogEntry>, List<Workout>)`.
- Checks:
  - Unit tests for `unlinkedExercises`: alternatives count as used, and names match case-insensitively.
  - Manual, on the phone: rename an exercise, find its old logs, move them, check that the Best chip comes back.

### Open points

- Names match case-insensitively and ignore extra spaces (`exerciseKey` in `lib/utils/exercise_name.dart`), so "bench  Press" and "Bench press" share one history. The match happens in Dart, because SQLite's `lower()` only folds ASCII.
- Optional: tapping an alternative chip in the editor renames it. Then A covers alternatives too.

## 2. Last week's values still fill the inputs

### What happens

- The kg and reps inputs on the workout screen are filled from the template, `ExerciseEntry.weight` and `.reps`. These are the values you last typed. **Save progress** and **Complete workout** store them.
- When a new week starts, `StartUpApp._normalizeWorkoutForCurrentWeek` clears only `lastCompletedWeekKey`. The values stay, so last week's numbers are in the inputs and easy to save again by mistake.
- There are two more gaps:
  - A workout that wasn't marked complete last week isn't reset at all, so it also keeps its values.
  - The reset only runs when workouts load: on app start, on a profile switch and on pull to refresh. If the app stays open from Sunday to Monday, the old values stay.

### Fix

1. Move the reset into a pure function next to the model, for example `Workout.forWeek(String weekKey)`. It does three things:
   - It clears `lastCompletedWeekKey` when it's from an earlier week, as now.
   - It clears `weight` and `reps` of every exercise when the workout was last changed in an earlier week (`weekKeyFor(updatedAt) != weekKey`). Every action that stores values also sets `updatedAt`, so this covers workouts that were completed and workouts that weren't.
   - It leaves `updatedAt` unchanged, so the order of the home list doesn't change.
2. Call it in `_loadWorkouts`, as now, and also when you open a workout or its editor. A workout opened after the week changed is then clean without a reload.
3. **Show last time's values as hints instead of values.** The workout screen already reads every log in `_loadBestWeights`. It can also keep the latest log of each exercise and show it as the inputs' `hintText`: a grey `80` and a grey `8`. The fields stay empty, so nothing old gets saved by accident, and you still see what you lifted last time.
   - The inputs have a `labelText`. Material hides the hint while a labeled field is empty and unfocused, so set `floatingLabelBehavior: FloatingLabelBehavior.always` to keep the hint visible.
4. The home subtitle "N updated" counts exercises that have values, so after the reset it shows 0. It now means "updated this week", which is correct.

Checks:
- Unit tests for `forWeek`:
  - In the same week, nothing changes.
  - From an earlier week, the values and the completion are cleared.
  - A workout changed last week but never completed is cleared too.
- Manual: set the phone's date to next Monday and open a workout. The inputs are empty and show hints.

Note: with sets (see [SETS_PLAN.md](SETS_PLAN.md)), the inputs are no longer filled from the template at all, so this fix is temporary. It's about 20 lines, so it's still worth shipping now.

## 3. Order

1. The weekly reset (section 2). It's independent and the smallest change.
2. The editor ids (section 1, "Bug found along the way").
3. Move logs on rename (A), then the repair tools (B).
4. Sets ([SETS_PLAN.md](SETS_PLAN.md)).

## 4. Decisions

- Logs lost after a rename: A + B.
- Weekly reset: clear the values of every workout changed in an earlier week.
- Show last time's values as grey hints.
- Exercise names match case-insensitively.
