import 'package:flutter/material.dart';
import 'package:gym_progression/widgets/set_row.dart';

/// Shows how to log sets, page by page. It opens by itself the first time a
/// workout is opened, and from the ? on the workout screen.
Future<void> showSetsGuide(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _SetsGuideDialog(),
  );
}

class _GuidePage {
  const _GuidePage({
    required this.title,
    required this.body,
    required this.illustration,
  });

  final String title;
  final String body;
  final List<Widget> illustration;
}

class _SetsGuideDialog extends StatefulWidget {
  const _SetsGuideDialog();

  @override
  State<_SetsGuideDialog> createState() => _SetsGuideDialogState();
}

class _SetsGuideDialogState extends State<_SetsGuideDialog> {
  final List<TextEditingController> _controllers = [];
  late final List<_GuidePage> _pages = _buildPages();
  int _page = 0;

  bool get _isLastPage => _page == _pages.length - 1;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// A set row with fixed values, drawn with the real set row widget.
  Widget _row(
    String label,
    SetRowState state, {
    String weight = '',
    String reps = '',
    String? weightHint,
    String? repsHint,
    bool isWarmup = false,
  }) {
    final weightController = TextEditingController(text: weight);
    final repsController = TextEditingController(text: reps);
    _controllers.addAll([weightController, repsController]);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SetRow(
        label: label,
        state: state,
        isWarmup: isWarmup,
        weight: weightController,
        reps: repsController,
        weightHint: weightHint,
        repsHint: repsHint,
      ),
    );
  }

  List<_GuidePage> _buildPages() {
    return [
      _GuidePage(
        title: 'Log a set',
        body: 'Type the weight and reps you lifted. A new empty row appears '
            'under it for the next set.',
        illustration: [
          const SetRowHeader(),
          _row('1', SetRowState.typed, weight: '80', reps: '8'),
          _row('2', SetRowState.empty, weightHint: '80', repsHint: '8'),
        ],
      ),
      _GuidePage(
        title: 'Grey numbers are hints',
        body: 'They show the set above or what you did last time. Hints are '
            'never saved: only what you type is.',
        illustration: [
          Builder(
            builder: (context) => Text(
              'Last time · 80×8 · 85×6 · 85×5',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          const SetRowHeader(),
          _row('1', SetRowState.empty, weightHint: '80', repsHint: '8'),
        ],
      ),
      _GuidePage(
        title: 'Warm-up sets',
        body: 'Tap a set number to mark it as a warm-up. Warm-ups are saved '
            'but left out of PRs and stats. Tap it again to undo.',
        illustration: [
          const SetRowHeader(),
          _row('W', SetRowState.typed, weight: '60', reps: '10', isWarmup: true),
          _row('1', SetRowState.typed, weight: '80', reps: '8'),
        ],
      ),
      _GuidePage(
        title: 'Save once',
        body: 'Save stores every set of the exercise. Save again whenever you '
            'like: edits update the same sets and nothing is duplicated. Save '
            'progress and Complete workout save every exercise, and going '
            'back asks before dropping unsaved sets.',
        illustration: [
          const SetRowHeader(),
          _row('W', SetRowState.saved, weight: '60', reps: '10', isWarmup: true),
          _row('1', SetRowState.saved, weight: '80', reps: '8'),
          _row('2', SetRowState.typed, weight: '85', reps: '6'),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save 1 set'),
          ),
        ],
      ),
    ];
  }

  void _goTo(int page) {
    if (page < 0 || page >= _pages.length) {
      return;
    }
    setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = _pages[_page];

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: GestureDetector(
                // Swipe between pages, like a tutorial.
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < 0) _goTo(_page + 1);
                  if (velocity > 0) _goTo(_page - 1);
                },
                child: SingleChildScrollView(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      key: ValueKey(_page),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          // Only a picture: the rows can't be typed in.
                          child: ExcludeFocus(
                            child: IgnorePointer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: page.illustration,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(page.title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(
                          page.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < _pages.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!_isLastPage)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Skip'),
                  ),
                const Spacer(),
                if (_page > 0)
                  TextButton(
                    onPressed: () => _goTo(_page - 1),
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLastPage
                      ? () => Navigator.of(context).pop()
                      : () => _goTo(_page + 1),
                  child: Text(_isLastPage ? 'Got it' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
