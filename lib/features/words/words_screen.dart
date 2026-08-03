import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/word.dart';
import '../../providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_section.dart';
import '../../widgets/word_row.dart';
import '../account/account_sheet.dart';
import 'add_word_sheet.dart';
import 'word_detail_sheet.dart';

enum _Sort {
  recent('Son eklenen'),
  alphabetical('A–Z'),
  mastery('Ustalık');

  const _Sort(this.label);
  final String label;
}

class WordsScreen extends ConsumerStatefulWidget {
  const WordsScreen({super.key});

  @override
  ConsumerState<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends ConsumerState<WordsScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  WordStatus? _filter;
  _Sort _sort = _Sort.recent;

  /// Alt çubuktan açılan "yalnızca eklediklerim" görünümü.
  bool _onlyCustom = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Word> _visible(List<Word> all) {
    final q = _query.trim().toLowerCase();
    final filtered = all.where((w) {
      if (_onlyCustom && !w.isCustom) return false;
      if (_filter != null && w.status != _filter) return false;
      if (q.isEmpty) return true;
      return w.term.toLowerCase().contains(q) ||
          w.translation.toLowerCase().contains(q);
    }).toList();

    filtered.sort(switch (_sort) {
      _Sort.recent => (a, b) => (b.addedAt ?? DateTime(1970))
          .compareTo(a.addedAt ?? DateTime(1970)),
      _Sort.alphabetical => (a, b) =>
          a.term.toLowerCase().compareTo(b.term.toLowerCase()),
      _Sort.mastery => (a, b) => b.mastery.compareTo(a.mastery),
    });
    return filtered;
  }

  Future<void> _togglePrekta(bool value) async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    try {
      await ref.read(userRepositoryProvider).setUsePrektaWords(uid, value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Ayar kaydedilemedi, tekrar dene.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(visibleWordsProvider);
    final all = wordsAsync.valueOrNull ?? const <Word>[];
    final words = _visible(all);
    final usePrekta = ref.watch(usePrektaWordsProvider);
    final customCount = ref.watch(customWordsProvider).valueOrNull?.length ?? 0;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.lg,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Kelimelerim', style: AppTextStyles.screenTitle),
                ),
                IconButton(
                  onPressed: () => showAddWordSheet(context),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Kelime ekle',
                ),
                IconButton(
                  onPressed: () => showAccountSheet(context),
                  icon: const Icon(Icons.person_outline),
                  tooltip: 'Hesabım',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Kelime ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: _PrektaToggle(
              value: usePrekta,
              onChanged: _togglePrekta,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _FilterChips(
            selected: _filter,
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    wordsAsync.isLoading && all.isEmpty
                        ? 'Yükleniyor...'
                        : '${words.length} kelime',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: _SortButton(
                    sort: _sort,
                    onChanged: (s) => setState(() => _sort = s),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            // Hata kartı dikeyde esnemesin diye üste hizalanır.
            child: wordsAsync.hasError && all.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH,
                    ),
                    child: Column(
                      children: [
                        ErrorRetryCard(
                          onRetry: () => ref.invalidate(wordsProvider),
                          message: 'Kelimelerin yüklenemedi. Bağlantını '
                              'kontrol edip tekrar dene.',
                        ),
                      ],
                    ),
                  )
                : AsyncSection<List<Word>>(
                    value: wordsAsync,
                    onRetry: () => ref.invalidate(wordsProvider),
                    skeleton: const _ListSkeleton(),
                    data: (_) => words.isEmpty
                        ? _EmptyState(
                            hasWords: all.isNotEmpty,
                            prektaOff: !usePrekta,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenH,
                              0,
                              AppSpacing.screenH,
                              AppSpacing.lg,
                            ),
                            itemCount: words.length,
                            itemBuilder: (context, i) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: AppCard(
                                padding: EdgeInsets.zero,
                                child: WordRow(
                                  word: words[i],
                                  onTap: () =>
                                      showWordDetail(context, words[i]),
                                ),
                              ),
                            ),
                          ),
                  ),
          ),
          _ArchiveBar(
            total: customCount,
            loading: wordsAsync.isLoading,
            active: _onlyCustom,
            onTap: customCount == 0
                ? null
                : () => setState(() => _onlyCustom = !_onlyCustom),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final WordStatus? selected;
  final ValueChanged<WordStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Yükseklik chip içeriğinden gelir; sabit yükseklik büyük yazı ölçeğinde
    // metni taşırıyordu.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      child: Row(
        children: [
          _Chip(
            label: 'Tümü',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final status in WordStatus.values)
            _Chip(
              label: status.label,
              selected: selected == status,
              onTap: () => onChanged(status),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        borderRadius: AppRadius.chipR,
        child: InkWell(
          borderRadius: AppRadius.chipR,
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadius.chipR,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: AppTextStyles.chip.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});

  final _Sort sort;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Sort>(
      initialValue: sort,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      itemBuilder: (_) => [
        for (final s in _Sort.values)
          PopupMenuItem(
            value: s,
            child: Text(s.label, style: AppTextStyles.body),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              sort.label,
              style: AppTextStyles.link,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasWords, this.prektaOff = false});

  final bool hasWords;

  /// Hazır havuz kapalı ve kullanıcının hiç kelimesi yok.
  final bool prektaOff;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 32,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              hasWords
                  ? 'Bu filtreye uyan kelime yok.'
                  : prektaOff
                      ? 'Henüz kendi kelimen yok.'
                      : 'Kelime dağarcığın henüz boş.',
              textAlign: TextAlign.center,
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasWords
                  ? 'Aramanı ya da filtreni değiştirmeyi dene.'
                  : prektaOff
                      ? 'Prekta kelimeleri kapalı. Kendi kelimeni ekle ya da '
                          'hazır havuzu tekrar aç.'
                      : 'Dil seçimini yaptığında başlangıç listen yüklenir. '
                          'Dilersen kendi kelimeni de ekleyebilirsin.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            if (!hasWords) ...[
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton(
                onPressed: () => showAddWordSheet(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Kelime ekle',
                      style: AppTextStyles.button
                          .copyWith(color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Prekta kelimeleri" anahtarı: hazır havuzu listeye ve pratiğe dahil eder.
/// Yanındaki ⓘ ne işe yaradığını anlatır.
class _PrektaToggle extends StatelessWidget {
  const _PrektaToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  void _explain(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Prekta kelimeleri', style: AppTextStyles.cardTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prekta\'nın hazır kelime havuzunu kullan ya da kullanma.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Açıkken: hazır havuz + senin eklediğin kelimeler birlikte '
              'listelenir ve pratikte sorulur.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Kapalıyken: yalnızca senin eklediğin kelimeler listelenir ve '
              'yalnızca onları çalışırsın. Hazır kelimeler silinmez, '
              'tekrar açtığında ilerlemesiyle birlikte geri gelir.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Eklediğin kelimeler yalnızca sana görünür, '
                    'başka kullanıcılarla paylaşılmaz.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 20,
            color: value ? AppColors.primary : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              'Prekta kelimeleri',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _explain(context),
            icon: const Icon(Icons.info_outline, size: 18),
            color: AppColors.textTertiary,
            visualDensity: VisualDensity.compact,
            tooltip: 'Bu ayar ne yapar?',
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: AppColors.trackNeutral,
          ),
        ],
      ),
    );
  }
}

/// Liste yüklenirken kelime satırlarının yerini tutan iskelet.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        0,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => const SkeletonCard(height: 84),
    );
  }
}

/// Alt sabit çubuk: kullanıcının kendi eklediği kelime sayısı. Dokununca
/// listeyi yalnızca o kelimelere daraltır.
class _ArchiveBar extends StatelessWidget {
  const _ArchiveBar({
    required this.total,
    this.loading = false,
    this.active = false,
    this.onTap,
  });

  final int total;
  final bool loading;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? AppColors.primarySurface : AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                Icons.bookmark_added_outlined,
                size: 18,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              // Etiket esner, sayaç sağda sabit kalır; ikisi de tek satır.
              Expanded(
                child: Text(
                  'Eklediklerin',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color:
                        active ? AppColors.primary : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  loading && total == 0 ? '—' : '$total kelime',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                Icon(
                  active ? Icons.expand_more : Icons.chevron_right,
                  size: 18,
                  color: active ? AppColors.primary : AppColors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
