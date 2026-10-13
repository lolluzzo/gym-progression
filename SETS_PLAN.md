# Plan: sets (series)

Status as of 2026-10-13: plan only. Revised from the 2026-10-07 version to match your request: once you fill a row a new one appears, and one save logs every set. Updated the same day with your decisions (section 6): one save, a warm-up flag, per-set reps in plans, hints that are never saved, and a first-run guide.

## 1. The concept

In a session, an exercise is a list of **sets**. Each set has a weight and a number of reps. Three or four sets is typical, and the weight often changes between them: ramping up (60 → 70 → 80) or dropping down.

## 2. Where the app is today

- `ExerciseEntry` holds one `weight` and one `reps`: the last values typed into the template.
- Each **Save log** inserts one row in `workout_logs`. Saving three times already records three sets. But the UI makes this awkward, and tapping twice saves the same set twice.
- History groups logs by workout and day, so it already shows one line per set.

**The database already models sets: one set is one log row.** The only schema change is the warm-up flag.

## 3. Data model

### One new column: `is_warmup`

The previous version of this plan added `set_index` and `session_id`. Neither one is needed:

- **Set order** is the row order (`id`). New sets are always added at the end, and editing a set updates its row in place, so the order holds. Old logs already count as one set each.
- **Session** = workout + day, the same key History already groups by. A `session_id` created when you open a workout would split one training in two each time you go back to the list and reopen the workout, which happens often. Two sessions of the same workout on the same day are rare. A session that crosses midnight also works, because saved sets keep their row id (see **Save** below).

The warm-up flag does need a column: `is_warmup INTEGER NOT NULL DEFAULT 0` on `workout_logs`. The DB goes from version 3 to 4: an `ALTER TABLE` in `onUpgrade`, and the column in `_ensureSchema` for new installs. Old logs become working sets.

### Template

- The inputs are no longer filled from `ExerciseEntry.weight`/`reps`. The JSON keeps those fields so old data still loads, but the app stops writing them. This also covers the weekly reset fix in [FIXES_PLAN.md](FIXES_PLAN.md), section 2.
- The home subtitle "N updated" reads those fields. Replace it with the number of exercises logged this week, counted from the logs.
- Planned sets with per-set reps come later (step 7). Rows grow as you fill them, so a plan isn't needed to start.

## 4. UI

Clickable prototype of this section: https://claude.ai/artifact/NCfq65wDJNoxGD5MsxovAF

### Workout screen, per exercise card

```
Bench press                          🏆 Best 85 kg
[Bench press] [Dumbbell press] [Machine]
Last time · 07/10   W 60×10 · 80×8 · 85×6 · 85×5

SET   KG          REPS
(W)   [ 60     ]  [ 10     ]   ✕    ← warm-up, saved
(1)   [ 80     ]  [ 8      ]   ✕    ← saved
 2    [ 85     ]  [ 6      ]   ✕    ← typed, not saved yet
 3    [ 85     ]  [ 6      ]        ← empty row, grey hints from set 2

[ Save 1 set ]          [ History ]
```

**Rows**

- **The last row is always empty.** When you type in it, a new empty row appears below it. That's the "new input appears" behavior, and there's no "Add set" button.
- An empty row shows **hints**: grey placeholders, not values. They come from the nearest working set above it. For the first working set, they come from the first working set of the last session. With a plan, the reps hint is the plan's target for that set (step 7). Hints are a reminder only: they're never saved.
  - The new row can't be pre-filled with real values. It would never be empty, so rows would keep appearing, and the last row would be saved too.
- **Save stores only what you typed.** A row with only a weight is saved without reps, and reps alone is fine for dips or pull-ups. Rows with nothing typed are skipped.
- **Warm-up:** tap a set's badge to switch it between working set and warm-up. A warm-up shows `W`, and working sets are numbered without them (W, W, 1, 2, 3). Warm-ups are saved and shown in history, dimmed, but every stat ignores them (see Stats).
- ✕ removes a row. Empty rows have no ✕.
- When a set is saved, its badge fills in. If you edit a saved set, the badge goes back to an outline until you save again.
- **Each form keeps its own rows.** When you switch form with the alternative chips, the card shows that form's sets for today. A dot on a chip marks a form with unsaved sets.
- Use column headers (SET, KG, REPS) instead of a `labelText` on each field. Material hides the hint of an empty field with a label until it's focused.

**Save**

- **Save N sets** (per exercise) writes every changed row in one transaction. Rows that already have a log id are updated, new rows are inserted, and rows removed with ✕ are deleted. Saving twice never creates duplicates, and you can fix a typo in set 2 and save again. The button shows "Saved" and is disabled when nothing is pending.
- **Save progress** and **Complete workout** first save the pending sets of every exercise, so typed sets aren't left behind. They no longer copy values into the template.
- Going back with unsaved sets asks "Discard unsaved sets?" (`PopScope`).
- Reopening the workout on the same day loads today's saved sets into the rows, so you continue where you left off.
- The PR celebration fires at most once per save: when the heaviest saved working set beats the best of earlier sessions. Warm-ups never trigger it.

**Why one save instead of a ✓ on each set** (the Strong/Hevy style the previous plan chose):

- It's what you asked for: fill a row and the next appears, then one save for all.
- It's one tap per exercise instead of one per set.
- Saving is cheap and never duplicates, so you can still tap it after every set if you want.
- Trade-off: sets you typed but didn't save are lost if the app is killed. The inputs have the same risk today.

### First-run guide

The first time you open a workout after this update, a modal explains how to log sets. It has 4 pages, each with a small illustration of the real set rows, plus dots, Skip, Back/Next, and Got it on the last page:

1. **Log a set:** type the weight and reps you lifted. A new empty row appears for the next set.
2. **Grey numbers are hints:** they come from the set above or from last time, or from the plan's target reps. They're never saved: only what you type is.
3. **Warm-ups:** tap a set number to mark it W. Warm-ups are saved but left out of PRs and stats. Tap again to undo.
4. **Save:** one tap saves every set of the exercise. Save again any time: edits update the same sets and nothing is duplicated. Save progress and Complete workout save every exercise, and going back asks before dropping unsaved sets.

- It shows once: a `sets_guide_seen` flag in `AppSettings` (SharedPreferences, next to `dark_mode`).
- A **?** button in the workout app bar opens it again.
- Flutter: `showDialog` with a `PageView`. The illustrations reuse the set row widget with fixed values, so the guide always matches the screen.

### History tab

Each exercise shows its sets on one line: `80×8 · 85×6 · 85×5`. Today each log gets its own `80 kg × 8 reps` line. A set without weight shows as `×12`. Warm-ups are dimmed and marked: `W 60×10 · 80×8 · …`.

### Exercise history screen

Today each log has its own card ("Log #3", a weight tile, a reps tile). With sets, that's 3–4 cards per session.

- **One card per session** (day + workout): the date, the workout name, a PR chip, the sets as compact rows (`1  80 kg × 8`, warm-ups as `W  60 kg × 10`, dimmed) and the volume.
- Swipe a set to delete it. Delete a whole session from the card's ⋮ menu.
- **Chart: one point per session, using the top set** (the heaviest working weight). Today it plots every log, which would put 3–4 points on each day.
- Tiles: Best, Latest (the latest session's top set) and PRs.

### Stats

- **Warm-ups:** every stat skips them: PRs, the chart's top set, Best, Latest and volume.
- **Volume:** the sum of weight × reps over the working sets. Today it sums every row, so it needs the warm-up filter.
- **PRs:** today, a PR is any log heavier than every earlier log. With sets, ramping up inside one session (80 → 85 → 87.5) counts as several PRs, and so does the ramp of the very first session. Change `personalRecordIds` so a session has **at most one PR**: its top set, compared with earlier sessions. This already happens today when you save the same exercise twice in one day.
- Later: an estimated 1RM (Epley: `w × (1 + reps / 30)`), so that 80×10 beats 85×2.

## 5. Steps

1. **Storage:** the `is_warmup` column (DB v4), `ExerciseLogStorage.saveSets(...)` (update, insert and delete in one transaction) and a query for today's sets of a workout.
   Check: a sqflite ffi test. Save 3 sets, edit one, remove one and save again: 2 rows are left, and they keep their original ids and times. A warm-up flag survives a save. A v3 database upgrades with every old log as a working set.
2. **Workout screen:** set rows with the always-empty last row, hints (never saved), the warm-up toggle, filled badges, the per-exercise save, Save progress and Complete saving everything, reloading today's sets, rows per form and the discard prompt.
   Check: a widget test (fill row 1 → row 2 appears; save → 1 log; edit and save → still 1 log; a row with only a weight saves no reps; tap a badge → it shows W and the next set is numbered 1), then a real session on the phone.
3. **First-run guide:** the 4-page modal, the `sets_guide_seen` flag and the ? button.
   Check: a widget test. The first open shows the guide, the second doesn't, and ? opens it again.
4. **Stats:** at most one PR per session, the top-set aggregation for the chart, and warm-ups skipped everywhere.
   Check: unit tests in `progress_stats_test.dart`. A ramp inside one session is one PR, the first session is the baseline, and a heavy warm-up is never a PR.
5. **History:** sets on one line in the History tab, and session cards in the exercise history, with warm-ups dimmed.
   Check: extend the `groupSessions` tests and the smoke test.
6. **Home subtitle:** exercises logged this week, from the logs.
7. **Later: planned sets with per-set reps.** `ExerciseEntry.targetReps: List<String>`, one entry per planned working set, each `8` or `8-10`. `4x8` is four equal entries, and a pyramid is `12/10/8`. The list length is the planned count, so there's no separate `plannedSets`.
   - Editor: one field that takes `4x8` or `12/10/8`.
   - Import parses both: `(\d+)\s*[x×]\s*(\d+(?:-\d+)?)\s*$` for `4x8`, and `(\d+(?:-\d+)?(?:\s*/\s*\d+(?:-\d+)?)+)\s*$` for `12/10/8`.
   - Card: it opens with one row per planned set, each with its target reps as the hint, and shows "1 of 3 sets". Warm-ups don't use up planned sets, so marking a row W adds an empty row back.

## 6. Decisions (2026-10-13)

- **One save for all sets.** See section 4, Save.
- **Warm-up flag: yes.** One column (section 3), a tap on the set badge (section 4), skipped by every stat.
- **Per-set reps in a plan: yes**, for example a 12/10/8 pyramid (step 7).
- **Hints are never saved.** Save stores only the fields you typed.
- **Warm-ups count in no stat**, volume included.
- **A saved set keeps its number** in a filled badge, so a saved warm-up still shows W.
- **First-run guide:** a modal tutorial the first time you open a workout, and again from ? (section 4).
