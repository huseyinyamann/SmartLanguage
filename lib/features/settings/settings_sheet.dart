import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/icon_box.dart';

/// Ayarlar: çıkış yap, hesabı kalıcı olarak sil.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  bool _busy = false;

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) navigator.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('Çıkış yapılamadı, tekrar dener misin?');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Hesabın silinsin mi?', style: AppTextStyles.cardTitle),
        content: Text(
          'Tüm kelimelerin, ilerlemen ve istatistiklerin kalıcı olarak '
          'silinir. Bu işlem geri alınamaz.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Hesabı sil',
              style: AppTextStyles.link.copyWith(
                color: AppColors.wordStruggling,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(userRepositoryProvider).deleteAllData(uid);
      await ref.read(authRepositoryProvider).deleteAccount();
      if (mounted) navigator.pop();
    } on SignInCancelled {
      if (mounted) setState(() => _busy = false);
    } on SignInFailure catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('Hesap silinemedi, tekrar dener misin?');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ayarlar', style: AppTextStyles.sectionTitle),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.logout_outlined,
                    background: AppColors.primarySurface,
                    foreground: AppColors.primary,
                    label: 'Çıkış yap',
                    disabled: _busy,
                    onTap: _signOut,
                  ),
                  const Divider(height: 1),
                  _SettingsRow(
                    icon: Icons.delete_forever_outlined,
                    background: AppColors.wordStruggling.withValues(
                      alpha: 0.12,
                    ),
                    foreground: AppColors.wordStruggling,
                    labelColor: AppColors.wordStruggling,
                    label: 'Hesabı sil',
                    disabled: _busy,
                    onTap: _confirmDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.label,
    required this.disabled,
    required this.onTap,
    this.labelColor,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String label;
  final Color? labelColor;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardPadding,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              IconBox(
                icon: icon,
                background: background,
                foreground: foreground,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.word.copyWith(
                    color: labelColor ?? AppColors.textPrimary,
                  ),
                ),
              ),
              if (disabled)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
