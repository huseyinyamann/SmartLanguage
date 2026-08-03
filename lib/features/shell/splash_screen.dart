import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/prekta_logo.dart';

/// Oturum çözümlenirken gösterilen ara ekran.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PrektaLogo(size: 96),
              const SizedBox(height: AppSpacing.lg),
              Text('Prekta', style: AppTextStyles.screenTitle),
              const SizedBox(height: AppSpacing.xs),
              Text('Kelime öğrenme', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.xxl),
              if (error == null)
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                )
              else ...[
                const Icon(
                  Icons.wifi_off_outlined,
                  color: AppColors.textTertiary,
                  size: 28,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Bağlantı kurulamadı. İnternetini kontrol edip uygulamayı '
                  'yeniden açar mısın?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
