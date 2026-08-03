import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

/// Firestore akışlarını arayüze bağlarken üç durumu da ayırt eder:
/// veri · yükleniyor (iskelet) · hata (tekrar dene).
///
/// Bunsuz `value ?? []` yazıldığında yükleniyor ile boş liste aynı görünür;
/// hata da sessizce yutulur.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.data,
    required this.skeleton,
    this.onRetry,
  });

  final AsyncValue<T> value;

  /// Veri geldiğinde çizilecek içerik.
  final Widget Function(T data) data;

  /// İlk yükleme sırasında gösterilecek iskelet.
  final Widget skeleton;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Yeniden yüklenirken elimizdeki veri korunur; ekran boşalmaz.
    final previous = value.valueOrNull;

    return value.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      data: data,
      loading: () => previous == null ? skeleton : data(previous),
      error: (_, _) => previous != null
          ? data(previous)
          : ErrorRetryCard(onRetry: onRetry),
    );
  }
}

/// Akış hata verdiğinde gösterilen kart.
class ErrorRetryCard extends StatelessWidget {
  const ErrorRetryCard({
    super.key,
    this.onRetry,
    this.message = 'Veriler yüklenemedi. Bağlantını kontrol edip tekrar dene.',
  });

  final VoidCallback? onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Bağlantı sorunu', style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: AppTextStyles.body),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onRetry,
                child: Text('Tekrar dene', style: AppTextStyles.link),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Yükleme iskeleti — içerik yerine duran nötr gri blok.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.radius = AppRadius.searchR,
  });

  final double height;
  final double? width;
  final BorderRadius radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.trackNeutral,
          borderRadius: widget.radius,
        ),
      ),
    );
  }
}

/// Kart görünümünde iskelet — kartların yerini korur.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, required this.height, this.width});

  final double height;

  /// Yatay şeritlerde gerekir: Row/ListView içinde genişlik sınırsızdır.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      height: height,
      width: width,
      radius: AppRadius.cardR,
    );
  }
}
