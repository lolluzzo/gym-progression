import 'package:flutter/material.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';

/// Whether a set row is empty, typed but not saved, or saved.
enum SetRowState { empty, typed, saved }

const double _badgeColumnWidth = 40;
const double _removeColumnWidth = 40;

/// "80×8", "×12" for a set without weight, "80 kg" for one without reps.
String formatSet(String? weight, String? reps) {
  if (weight == null) {
    // Logs saved before sets could have no values at all.
    return reps == null ? '–' : '×$reps';
  }
  return reps == null ? '$weight kg' : '$weight×$reps';
}

/// Sets on one line, "W 60×10 · 80×8 · 85×6", with warm-ups dimmed.
TextSpan setsLineSpan(BuildContext context, List<ExerciseLogEntry> sets) {
  final dimmed = TextStyle(
    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
          alpha: 0.6,
        ),
  );

  return TextSpan(
    children: [
      for (final (index, set) in sets.indexed) ...[
        if (index > 0) const TextSpan(text: ' · '),
        TextSpan(
          text: '${set.isWarmup ? 'W ' : ''}${formatSet(set.weight, set.reps)}',
          style: set.isWarmup ? dimmed : null,
        ),
      ],
    ],
  );
}

/// The SET, KG and REPS labels above the set rows. The fields have no label
/// of their own, because Material hides the hint of an empty labeled field.
class SetRowHeader extends StatelessWidget {
  const SetRowHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.8,
    );

    return Row(
      children: [
        SizedBox(
          width: _badgeColumnWidth,
          child: Text('SET', style: style, textAlign: TextAlign.center),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text('KG', style: style)),
        const SizedBox(width: 8),
        Expanded(child: Text('REPS', style: style)),
        const SizedBox(width: _removeColumnWidth),
      ],
    );
  }
}

/// One set: its number, or W for a warm-up, the kg and reps fields, and a
/// remove button. Hints are grey placeholders and are never saved.
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.label,
    required this.state,
    required this.isWarmup,
    required this.weight,
    required this.reps,
    this.weightHint,
    this.repsHint,
    this.onChanged,
    this.onToggleWarmup,
    this.onRemove,
  });

  final String label;
  final SetRowState state;
  final bool isWarmup;
  final TextEditingController weight;
  final TextEditingController reps;
  final String? weightHint;
  final String? repsHint;
  final VoidCallback? onChanged;
  final VoidCallback? onToggleWarmup;

  /// Null hides the remove button.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final valueStyle =
        isWarmup ? TextStyle(color: colors.onSurfaceVariant) : null;

    InputDecoration decoration(String? hint) {
      return InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        enabledBorder: state == SetRowState.saved
            ? OutlineInputBorder(
                borderSide: BorderSide(color: colors.outlineVariant),
              )
            : null,
      );
    }

    return Row(
      children: [
        SizedBox(
          width: _badgeColumnWidth,
          child: Center(
            child: SetBadge(
              label: label,
              state: state,
              isWarmup: isWarmup,
              onTap: onToggleWarmup,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: valueStyle,
            decoration: decoration(weightHint),
            onChanged: (_) => onChanged?.call(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: reps,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            style: valueStyle,
            decoration: decoration(repsHint),
            onChanged: (_) => onChanged?.call(),
          ),
        ),
        SizedBox(
          width: _removeColumnWidth,
          child: onRemove == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove set',
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                ),
        ),
      ],
    );
  }
}

/// The round set number. It's outlined while typed, filled once saved, and
/// uses the tertiary color for a warm-up.
class SetBadge extends StatelessWidget {
  const SetBadge({
    super.key,
    required this.label,
    required this.state,
    required this.isWarmup,
    this.onTap,
  });

  final String label;
  final SetRowState state;
  final bool isWarmup;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = isWarmup ? colors.tertiary : colors.primary;
    final saved = state == SetRowState.saved;

    final Color? borderColor;
    final Color textColor;
    if (saved) {
      borderColor = null;
      textColor = isWarmup ? colors.onTertiary : colors.onPrimary;
    } else if (isWarmup) {
      borderColor = accent;
      textColor = accent;
    } else if (state == SetRowState.typed) {
      borderColor = colors.outline;
      textColor = colors.onSurface;
    } else {
      borderColor = null;
      textColor = colors.onSurfaceVariant;
    }

    return Tooltip(
      message: isWarmup
          ? 'Warm-up. Tap to make it a working set'
          : 'Tap to mark as warm-up',
      child: Material(
        color: saved ? accent : Colors.transparent,
        shape: CircleBorder(
          side: borderColor == null
              ? BorderSide.none
              : BorderSide(color: borderColor, width: 1.5),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 32,
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: textColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
