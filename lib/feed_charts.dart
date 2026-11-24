import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A daily-feed sample for one feed type, x-axis = bird age in days.
class AgeFeedPoint {
  final int ageDays;
  final double feedKg;

  const AgeFeedPoint(this.ageDays, this.feedKg);
}

/// Bird age (days) vs daily feed (kg) — one line per feed type.
///
/// [series] maps feed type -> points of that type. Lines are drawn with
/// straight segments and visible dots (feeds are recorded on most days, but
/// gaps must not silently become slopes).
class FeedTypeLineChart extends StatelessWidget {
  final Map<String, List<AgeFeedPoint>> series;
  final List<Color> palette;

  const FeedTypeLineChart({
    super.key,
    required this.series,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final entries = series.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    double maxAge = 0;
    double maxFeed = 0;
    for (final list in series.values) {
      for (final p in list) {
        if (p.ageDays > maxAge) maxAge = p.ageDays.toDouble();
        if (p.feedKg > maxFeed) maxFeed = p.feedKg;
      }
    }
    final ageMax = maxAge <= 0 ? 1.0 : maxAge;
    final feedMax = maxFeed <= 0 ? 1.0 : maxFeed * 1.15;

    return Column(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: feedMax,
              minX: 0,
              maxX: ageMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _niceInterval(feedMax),
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.25),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text(
                    'Bird age (days)',
                    style: TextStyle(fontSize: 10),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: _niceInterval(ageMax),
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        v % 1 == 0 ? v.toInt().toString() : '',
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: const Text(
                    'Feed (kg)',
                    style: TextStyle(fontSize: 10),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: _niceInterval(feedMax),
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        v >= 100
                            ? v.toStringAsFixed(0)
                            : v.toStringAsFixed(v % 1 == 0 ? 0 : 1),
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(
                touchTooltipData: LineTouchTooltipData(),
              ),
              lineBarsData: [
                for (var i = 0; i < entries.length; i++)
                  LineChartBarData(
                    spots: entries[i].value
                        .map((p) => FlSpot(p.ageDays.toDouble(), p.feedKg))
                        .toList(),
                    isCurved: false,
                    barWidth: 2.2,
                    dotData: const FlDotData(show: true),
                    color: palette[i % palette.length],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (var i = 0; i < entries.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette[i % palette.length],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(entries[i].key, style: const TextStyle(fontSize: 10)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  double _niceInterval(double max) {
    final raw = max / 4;
    if (raw <= 0) return 1;
    var pow = 1.0;
    while (pow * 10 <= raw) {
      pow *= 10;
    }
    while (pow > raw) {
      pow /= 10;
    }
    for (final m in [1.0, 2.0, 5.0, 10.0]) {
      if (m * pow >= raw) return m * pow;
    }
    return 10 * pow;
  }
}

/// FCR (kg feed / kg gain) per feed type — horizontal-ish bar chart with
/// value labels above every bar.
class FcrByTypeBarChart extends StatelessWidget {
  final Map<String, double> fcrByType;
  final Color barColor;
  final Color labelColor;

  const FcrByTypeBarChart({
    super.key,
    required this.fcrByType,
    required this.barColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final entries = fcrByType.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    final maxFcr = entries.fold<double>(0, (m, e) => m > e.value ? m : e.value);
    final yMax = maxFcr <= 0 ? 1.0 : maxFcr * 1.25;

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: yMax,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yMax / 4,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: Colors.grey.withValues(alpha: 0.25), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Text(
              'Feed type',
              style: TextStyle(fontSize: 10),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Transform.rotate(
                    angle: entries.length > 3 ? -0.5 : 0,
                    child: Text(
                      entries[i].key,
                      style: const TextStyle(fontSize: 9),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Text(
              'FCR (kg/kg)',
              style: TextStyle(fontSize: 10),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: yMax / 4,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  v.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 9),
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, i, rod, j) => BarTooltipItem(
              '${entries[group.x].key}\n${rod.toY.toStringAsFixed(2)} kg/kg',
              const TextStyle(fontSize: 10),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  color: barColor.withValues(alpha: 0.85),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
