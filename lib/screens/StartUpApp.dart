import 'package:flutter/material.dart';
import 'package:gym_progression/models/achievement.dart';
import 'package:gym_progression/models/profile.dart';
import 'package:gym_progression/models/workout.dart';
import 'package:gym_progression/screens/clients_screen.dart';
import 'package:gym_progression/screens/history_screen.dart';
import 'package:gym_progression/screens/import_workouts_screen.dart';
import 'package:gym_progression/screens/profile_screen.dart';
import 'package:gym_progression/screens/settings_screen.dart';
import 'package:gym_progression/screens/workout_detail_screen.dart';
import 'package:gym_progression/screens/workout_editor_screen.dart';
import 'package:gym_progression/services/app_settings.dart';
import 'package:gym_progression/services/completion_storage.dart';
import 'package:gym_progression/services/profile_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
import 'package:gym_progression/services/shared_text.dart';
import 'package:gym_progression/services/workout_storage.dart';
import 'package:gym_progression/utils/week.dart';
import 'package:gym_progression/widgets/celebration.dart';
import 'package:gym_progression/widgets/profile_avatar.dart';
import 'package:gym_progression/widgets/week_progress_card.dart';

class StartUpApp extends StatefulWidget {
  const StartUpApp({super.key});

  @override
  State<StartUpApp> createState() => _StartUpAppState();
}

class _StartUpAppState extends State<StartUpApp> {
  bool _isLoading = true;
  List<Workout> _workouts = [];
  Profile? _profile;
  int _streak = 0;
  int _tabIndex = 0;

  String get _currentWeekKey => weekKeyFor(DateTime.now());

  String get _profileId => _profile?.id ?? Profile.ownerId;

  @override
  void initState() {
    super.initState();
    _loadProfile().then((_) {
      // Workouts load first, so imported ones are added to them instead of
      // replacing them.
      if (mounted) {
        SharedText.listen(_openImport);
      }
    });
  }

  /// Loads the active profile, and its workouts when the profile changed.
  /// Without trainer mode the owner is always active.
  Future<void> _loadProfile() async {
    final profileId = AppSettings.instance.trainerMode
        ? await ProfileStorage.loadActiveProfileId()
        : Profile.ownerId;
    final profile = await ProfileStorage.loadProfile(profileId);
    if (!mounted) {
      return;
    }

    final profileChanged = profile.id != _profile?.id;
    setState(() => _profile = profile);

    if (profileChanged) {
      await _loadWorkouts();
    }
  }

  Future<void> _loadWorkouts() async {
    setState(() => _isLoading = true);

    try {
      final workouts = await WorkoutStorage.loadWorkouts(_profileId);
      final normalizedWorkouts =
          workouts.map(_normalizeWorkoutForCurrentWeek).toList();
      if (!mounted) {
        return;
      }

      setState(() {
        _workouts = normalizedWorkouts;
        _isLoading = false;
      });

      await WorkoutStorage.saveWorkouts(_profileId, normalizedWorkouts);
      await _loadStreak();
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

    await WorkoutStorage.saveWorkouts(_profileId, sortedWorkouts);
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

  Future<void> _openImport([String initialText = '']) async {
    final workouts = await Navigator.of(context).push<List<Workout>>(
      MaterialPageRoute(
        builder: (_) => ImportWorkoutsScreen(initialText: initialText),
      ),
    );

    if (workouts == null || workouts.isEmpty) {
      return;
    }

    await _saveWorkouts([..._workouts, ...workouts]);
    if (!mounted) {
      return;
    }

    setState(() => _tabIndex = 0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          workouts.length == 1
              ? 'Imported 1 workout.'
              : 'Imported ${workouts.length} workouts.',
        ),
      ),
    );
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
        builder: (_) => WorkoutDetailScreen(
          workout: workout,
          profileId: _profileId,
        ),
      ),
    );

    if (updatedWorkout == null) {
      return;
    }

    final workouts = _workouts
        .map((item) => item.id == updatedWorkout.id ? updatedWorkout : item)
        .toList();

    await _saveWorkouts(workouts);

    final wasCompleted = _isCompletedThisWeek(workout);
    final isCompleted = _isCompletedThisWeek(updatedWorkout);
    if (wasCompleted == isCompleted) {
      return;
    }

    final statsBefore = await ProfileStats.load(_profileId);
    if (isCompleted) {
      await CompletionStorage.addCompletion(
        profileId: _profileId,
        workout: updatedWorkout,
        weekKey: _currentWeekKey,
      );
    } else {
      await CompletionStorage.removeCompletion(
        profileId: _profileId,
        workoutId: updatedWorkout.id,
        weekKey: _currentWeekKey,
      );
    }

    final stats = await ProfileStats.load(_profileId);
    if (!mounted) {
      return;
    }

    setState(() => _streak = stats.currentStreak);

    if (isCompleted) {
      await showCelebration(
        context,
        icon: stats.isPerfectWeek
            ? Icons.workspace_premium_rounded
            : Icons.local_fire_department_rounded,
        title: stats.isPerfectWeek ? 'Perfect week!' : 'Workout complete!',
        message: stats.isPerfectWeek
            ? 'All ${stats.plannedThisWeek} workouts done this week. ${stats.currentStreak}-week streak and counting.'
            : '${updatedWorkout.name} done. ${stats.completedThisWeek} of ${stats.plannedThisWeek} this week · ${stats.currentStreak}-week streak.',
        unlocked: newlyUnlocked(statsBefore, stats),
      );
    }
  }

  Future<void> _loadStreak() async {
    final stats = await ProfileStats.load(_profileId);
    if (!mounted) {
      return;
    }

    setState(() => _streak = stats.currentStreak);
  }

  Future<void> _openProfile(Profile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(profile: profile)),
    );
    await _loadProfile();
  }

  Future<void> _openClients() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientsScreen(activeProfileId: _profileId),
      ),
    );
    await _loadProfile();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    await _loadProfile();
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

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(
        leading: profile == null
            ? null
            : IconButton(
                onPressed: () => _openProfile(profile),
                icon: Hero(
                  tag: 'avatar-${profile.id}',
                  child: ProfileAvatar(profile: profile, radius: 16),
                ),
                tooltip: 'Profile',
              ),
        title: Text(
          _tabIndex == 1
              ? 'History'
              : profile == null || profile.isOwner
                  ? 'My Workouts'
                  : profile.name,
        ),
        actions: [
          if (_tabIndex == 0)
            IconButton(
              onPressed: _openImport,
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Import from notes',
            ),
          if (AppSettings.instance.trainerMode)
            IconButton(
              onPressed: _openClients,
              icon: const Icon(Icons.groups_outlined),
              tooltip: 'Clients',
            ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openNewWorkout,
              icon: const Icon(Icons.add),
              label: const Text('Add workout'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
      body: _tabIndex == 1
          // Keyed by profile so switching client reloads the history.
          ? HistoryView(key: ValueKey(_profileId), profileId: _profileId)
          : _isLoading
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
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _openImport,
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Import from notes'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadWorkouts,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: _workouts.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return WeekProgressCard(
                              completed:
                                  _workouts.where(_isCompletedThisWeek).length,
                              planned: _workouts.length,
                              streak: _streak,
                            );
                          }

                          final workout = _workouts[index - 1];
                          final isCompleted = _isCompletedThisWeek(workout);
                          return Card(
                            color: isCompleted
                                ? Colors.green.withOpacity(0.12)
                                : null,
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
