import 'package:flutter/material.dart';
import 'package:gym_progression/models/achievement.dart';
import 'package:gym_progression/models/profile.dart';
import 'package:gym_progression/services/profile_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
import 'package:gym_progression/widgets/dialogs.dart';
import 'package:gym_progression/widgets/profile_avatar.dart';
import 'package:gym_progression/widgets/week_progress_card.dart';
import 'package:image_picker/image_picker.dart';

enum _PhotoAction { gallery, camera, remove }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  late Profile _profile = widget.profile;
  ProfileStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await ProfileStats.load(_profile.id);
    if (!mounted) {
      return;
    }

    setState(() => _stats = stats);
  }

  Future<void> _saveProfile(Profile profile) async {
    await ProfileStorage.saveProfile(profile);
    if (!mounted) {
      return;
    }

    setState(() => _profile = profile);
  }

  Future<void> _editName() async {
    final name = await showNameDialog(
      context,
      title: 'Edit name',
      initialName: _profile.name,
    );
    if (name == null) {
      return;
    }

    await _saveProfile(_profile.copyWith(name: name));
  }

  Future<void> _changePhoto() async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(_PhotoAction.gallery),
            ),
            if (_picker.supportsImageSource(ImageSource.camera))
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(context).pop(_PhotoAction.camera),
              ),
            if (_profile.imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (action == null) {
      return;
    }

    try {
      final previousImagePath = _profile.imagePath;

      if (action == _PhotoAction.remove) {
        await _saveProfile(_profile.copyWith(clearImage: true));
        await ProfileStorage.deleteImage(previousImagePath);
        return;
      }

      final picked = await _picker.pickImage(
        source: action == _PhotoAction.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) {
        return;
      }

      final imagePath = await ProfileStorage.saveImage(_profile.id, picked.path);
      await _saveProfile(_profile.copyWith(imagePath: imagePath));
      await ProfileStorage.deleteImage(previousImagePath);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update the photo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = _stats;

    String weeks(int count) => count == 1 ? '1 week' : '$count weeks';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: scheme.primaryContainer,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surface,
                      ),
                      child: Hero(
                        tag: 'avatar-${_profile.id}',
                        child: ProfileAvatar(profile: _profile, radius: 60),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        onPressed: _changePhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                        tooltip: 'Change photo',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        _profile.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: _editName,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit name',
                    ),
                  ],
                ),
                if (stats != null) StreakChip(streak: stats.currentStreak),
              ],
            ),
          ),
          if (stats == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _HeroStat(
                value: '${stats.totalCompleted}',
                label: 'Workouts completed',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _TwoColumnGrid(
                children: [
                  _StatTile(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Current streak',
                    value: weeks(stats.currentStreak),
                  ),
                  _StatTile(
                    icon: Icons.whatshot_rounded,
                    label: 'Best streak',
                    value: weeks(stats.bestStreak),
                  ),
                  _StatTile(
                    icon: Icons.emoji_events_rounded,
                    label: 'Personal records',
                    value: '${stats.personalRecords}',
                  ),
                  _StatTile(
                    icon: Icons.scale_rounded,
                    label: 'Total volume',
                    value: formatVolume(stats.totalVolumeKg),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Achievements',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${achievements.where((a) => a.isUnlockedBy(stats)).length} / ${achievements.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TwoColumnGrid(
                children: [
                  for (final achievement in achievements)
                    _AchievementTile(achievement: achievement, stats: stats),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays children out two per row; each row is as tall as its tallest tile.
class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: children[i]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < children.length
                        ? children[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.fitness_center_rounded,
            size: 56,
            color: scheme.onPrimary.withValues(alpha: 0.35),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.stats});

  final Achievement achievement;
  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUnlocked = achievement.isUnlockedBy(stats);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isUnlocked ? null : scheme.surfaceContainerHigh,
        gradient: isUnlocked
            ? LinearGradient(
                colors: [scheme.tertiaryContainer, scheme.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUnlocked ? scheme.primary : scheme.surfaceContainerHighest,
            ),
            child: Icon(
              isUnlocked ? achievement.icon : Icons.lock_outline_rounded,
              color: isUnlocked ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            achievement.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isUnlocked ? scheme.onPrimaryContainer : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            achievement.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isUnlocked
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          if (!isUnlocked) ...[
            const Spacer(),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: achievement.progressFor(stats),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              achievement.progressLabel(stats),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
