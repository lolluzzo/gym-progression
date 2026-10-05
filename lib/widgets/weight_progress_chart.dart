import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_progression/services/exercise_log_storage.dart';
import 'package:gym_progression/services/progress_stats.dart';

/// Chart colors, checked for color-blind separation and contrast against the
/// card surface in both themes. The Material scheme colors fail those checks.
class ChartColors {
  ChartColors._();

  static Color line(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFFD95926)
      : const Color(0xFFEB6834);

  static Color record(Brightness brightness) => brightness == Brightness.dark
      ? const Color(0xFF3987E5)
      : const Color(0xFF2A78D6);
}

/// Weight per session for one exercise. Personal records are larger blue
/// points. Expects [logs] oldest first, each with a numeric weight.
class WeightProgressChart extends StatelessWidget {
  const WeightProgressChart({
    super.key,
    required this.logs,
    required this.recordIds,
  });

  final List<ExerciseLogEntry> logs;
  final Set<int> recordIds;

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}/${twoDigits(local.month)}';
  }

  /// First, last and two evenly spaced dates, so labels never collide.
  bool _showsDateAt(int index) {
    final last = logs.length - 1;
    if (logs.length <= 4) {
      return true;
    }

    return index == 0 ||
        index == last ||
        index == (last / 3).round() ||
        index == (last * 2 / 3).round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lineColor = ChartColors.line(theme.brightness);
    final recordColor = ChartColors.record(theme.brightness);
    final surface = scheme.surfaceContainerLow;
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final weights = logs.map((log) => parseMetric(log.weight)!).toList();
    final minWeight = weights.reduce(math.min);
    final maxWeight = weights.reduce(math.max);
    final padding = math.max(2.5, (maxWeight - minWeight) * 0.2);

    bool isRecord(int index) => recordIds.contains(logs[index].id);

    FlDotPainter dotPainter(int index, {bool touched = false}) {
      final record = isRecord(index);
      return FlDotCirclePainter(
        radius: (record ? 6 : 4) + (touched ? 2 : 0),
        color: record ? recordColor : lineColor,
        strokeWidth: 2,
        strokeColor: surface,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.6,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (logs.length - 1).toDouble(),
              minY: math.max(0, (minWeight - padding).floorToDouble()),
              maxY: (maxWeight + padding).ceilToDouble(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    minIncluded: false,
                    maxIncluded: false,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(formatNumber(value), style: axisStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index != value || !_showsDateAt(index)) {
                        return const SizedBox.shrink();
                      }

                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          _formatDate(logs[index].loggedAt),
                          style: axisStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchSpotThreshold: 24,
                getTouchedSpotIndicator: (bar, indexes) => indexes
                    .map(
                      (index) => TouchedSpotIndicatorData(
                        FlLine(color: scheme.outline, strokeWidth: 1),
                        FlDotData(
                          getDotPainter: (_, __, ___, index) =>
                              dotPainter(index, touched: true),
                        ),
                      ),
                    )
                    .toList(),
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  tooltipBorderRadius: BorderRadius.circular(12),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => spots.map((spot) {
                    final log = logs[spot.spotIndex];
                    final record = isRecord(spot.spotIndex);
                    return LineTooltipItem(
                      '${formatNumber(spot.y)} kg',
                      TextStyle(
                        color: scheme.onInverseSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '\n${_formatDate(log.loggedAt)}${record ? ' · PR' : ''}',
                          style: TextStyle(
                            color: scheme.onInverseSurface
                                .withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < weights.length; i++)
                      FlSpot(i.toDouble(), weights[i]),
                  ],
                  isCurved: true,
                  curveSmoothness: 0.25,
                  preventCurveOverShooting: true,
                  color: lineColor,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  belowBarData: BarAreaData(
                    show: true,
                    color: lineColor.withValues(alpha: 0.1),
                  ),
                  dotData: FlDotData(
                    getDotPainter: (_, __, ___, index) => dotPainter(index),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _LegendKey(
              label: 'Weight per session',
              mark: Container(width: 16, height: 2, color: lineColor),
            ),
            _LegendKey(
              label: 'Personal record',
              mark: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: recordColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendKey extends StatelessWidget {
  const _LegendKey({required this.label, required this.mark});

  final String label;
  final Widget mark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
