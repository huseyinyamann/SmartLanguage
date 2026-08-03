import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../home/home_screen.dart';
import '../progress/progress_screen.dart';
import '../words/words_screen.dart';

/// Üç sekmeli ana iskelet: Ana Sayfa · Kelimelerim · Profil.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka planda gün değiştirmiş olabilir; "bugün"ü tazele.
    if (state == AppLifecycleState.resumed) refreshNow(ref);
  }

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // Eski sürümden kalan havuz kopyalarını bir kez temizler (arka planda).
    ref.watch(poolMigrationProvider);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onSeeAllWords: () => _goTo(1),
            onSeeProgress: () => _goTo(2),
          ),
          const WordsScreen(),
          const ProgressScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Ana Sayfa'),
    (
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      label: 'Kelimelerim',
    ),
    (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].icon,
                    activeIcon: _items[i].activeIcon,
                    label: _items[i].label,
                    active: i == index,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textTertiary;

    return InkWell(
      borderRadius: AppRadius.navPillR,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: active ? AppColors.primarySurface : Colors.transparent,
          borderRadius: AppRadius.navPillR,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon, size: 22, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.navLabel.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
