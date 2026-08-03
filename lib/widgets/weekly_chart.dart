import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/date_key.dart';
import '../core/models/daily_stat.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Haftalık aktivite: tek seri, yumuşak `primary` eğri, altında çok hafif
/// dolgu, grid çizgisi yok.
class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key, required this.days});

  /// Eskiden yeniye 7 gün.
  final List<DailyStat> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox(height: 160);

    final spots = [
      for (var i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].answered.toDouble()),
    ];
    final maxY = spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY < 4 ? 4 : maxY * 1.25,
          minX: 0,
          maxX: (days.length - 1).toDouble(),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  final date = parseDateKey(days[i].day);
                  if (date == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      weekdayShort(date),
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
