import 'package:flutter/material.dart';
import 'package:gym_progression/models/profile.dart';
import 'package:gym_progression/services/profile_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';
import 'package:gym_progression/widgets/dialogs.dart';
import 'package:gym_progression/widgets/profile_avatar.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.activeProfileId});

  final String activeProfileId;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  bool _isLoading = true;
  Profile? _owner;
  List<(Profile, ProfileStats)> _clients = [];
  ProfileStats? _ownerStats;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  /// Clients ranked by streak, then this week's progress, then total workouts.
  Future<void> _loadProfiles() async {
    final profiles = await ProfileStorage.loadProfiles();
    final ranked = <(Profile, ProfileStats)>[];
    Profile? owner;
    ProfileStats? ownerStats;

    for (final profile in profiles) {
      final stats = await ProfileStats.load(profile.id);
      if (profile.isOwner) {
        owner = profile;
        ownerStats = stats;
      } else {
        ranked.add((profile, stats));
      }
    }

    ranked.sort((a, b) {
      final byStreak = b.$2.currentStreak.compareTo(a.$2.currentStreak);
      if (byStreak != 0) {
        return byStreak;
      }
      final byWeek = b.$2.weekProgress.compareTo(a.$2.weekProgress);
      if (byWeek != 0) {
        return byWeek;
      }
      return b.$2.totalCompleted.compareTo(a.$2.totalCompleted);
    });

    if (!mounted) {
      return;
    }

    setState(() {
      _owner = owner;
      _ownerStats = ownerStats;
      _clients = ranked;
      _isLoading = false;
    });
  }

  Future<void> _selectProfile(Profile profile) async {
    await ProfileStorage.setActiveProfileId(profile.id);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _addClient() async {
    final name = await showNameDialog(context, title: 'New client');
    if (name == null) {
      return;
    }

    await ProfileStorage.saveProfile(
      Profile(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name),
    );
    await _loadProfiles();
  }

  Future<void> _deleteClient(Profile profile) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${profile.name}?',
      message:
          'Their workouts, logs, history and photo will be removed from this device.',
    );
    if (!confirmed) {
      return;
    }

    await ProfileStorage.deleteProfile(profile);
    await _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owner = _owner;
    final ownerStats = _ownerStats;

    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addClient,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add client'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                if (owner != null && ownerStats != null)
                  _ClientCard(
                    profile: owner,
                    stats: ownerStats,
                    title: '${owner.name} (you)',
                    isActive: owner.id == widget.activeProfileId,
                    onTap: () => _selectProfile(owner),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.leaderboard_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Leaderboard',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_clients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Add a client to track their workouts and logs separately. Tap a profile to switch to it.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                for (var i = 0; i < _clients.length; i++)
                  _ClientCard(
                    profile: _clients[i].$1,
                    stats: _clients[i].$2,
                    title: _clients[i].$1.name,
                    rank: i + 1,
                    isActive: _clients[i].$1.id == widget.activeProfileId,
                    onTap: () => _selectProfile(_clients[i].$1),
                    onDelete: () => _deleteClient(_clients[i].$1),
                  ),
              ],
            ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.profile,
    required this.stats,
    required this.title,
    required this.isActive,
    required this.onTap,
    this.rank,
    this.onDelete,
  });

  final Profile profile;
  final ProfileStats stats;
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final int? rank;
  final VoidCallback? onDelete;

  static const _medalColors = [
    Color(0xFFFFC107),
    Color(0xFFB0BEC5),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rank = this.rank;
    final hasMedal = rank != null && rank <= 3 && stats.totalCompleted > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isActive ? scheme.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isActive
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            children: [
              if (rank != null) ...[
                SizedBox(
                  width: 32,
                  child: hasMedal
                      ? Icon(
                          Icons.workspace_premium_rounded,
                          color: _medalColors[rank - 1],
                          size: 28,
                        )
                      : Text(
                          '#$rank',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surface,
                ),
                child: ProfileAvatar(profile: profile, radius: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        _InlineStat(
                          icon: Icons.local_fire_department_rounded,
                          label: '${stats.currentStreak} wk',
                        ),
                        _InlineStat(
                          icon: Icons.check_circle_outline_rounded,
                          label: '${stats.totalCompleted} done',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: stats.weekProgress,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          stats.plannedThisWeek == 0
                              ? 'No plan'
                              : '${(stats.weekProgress * 100).round()}% this week',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete client',
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
