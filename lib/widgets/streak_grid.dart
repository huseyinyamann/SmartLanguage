import 'package:flutter/material.dart';

import '../core/date_key.dart';
import '../core/models/daily_stat.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Katkı takvimi: 10 kolon × 3 satır. Çalışılan gün yeşil + ✓,
/// bugün mavi çerçeve, boş gün nötr.
class StreakGrid extends StatelessWidget {
  const StreakGrid({super.key, required this.days, required this.today});

  /// Eskiden yeniye 30 gün.
  final List<DailyStat> days;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final todayKey = dateKey(today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          children: [
            for (final day in days)
              _Cell(studied: day.studied, isToday: day.day == todayKey),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // Dar ekranda / büyük yazıda açıklamalar alt satıra iner.
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          children: [
            _Legend(color: AppColors.success, label: 'Çalışıldı'),
            _Legend(color: AppColors.primary, label: 'Bugün'),
            _Legend(color: AppColors.trackNeutral, label: 'Boş'),
          ],
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.studied, required this.isToday});

  final bool studied;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: studied ? AppColors.success : AppColors.trackNeutral,
        borderRadius: AppRadius.calendarCellR,
        border: isToday
            ? Border.all(color: AppColors.primary, width: 1.6)
            : null,
      ),
      child: studied
          ? const Center(
              child: Icon(Icons.check, size: 11, color: Colors.white),
            )
          : isToday
              ? const Center(
                  child: SizedBox(
                    width: 4,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                )
              : null,
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
