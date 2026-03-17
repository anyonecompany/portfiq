import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import 'etf_models.dart';
import 'my_etf_provider.dart';

/// ETF 추가 바텀시트.
class AddEtfSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const AddEtfSheet({super.key, required this.scrollController});

  @override
  ConsumerState<AddEtfSheet> createState() => _AddEtfSheetState();
}

class _AddEtfSheetState extends ConsumerState<AddEtfSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // 초기에 인기 ETF 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myEtfProvider.notifier).searchEtfs('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      EventTracker.instance.track('etf_search', properties: {
        'query': query,
      });
      EventTracker.instance.track('etf_search_used', properties: {
        'query': query,
        'source': 'my_etf',
      });
      ref.read(myEtfProvider.notifier).searchEtfs(query);
    });
  }

  Future<void> _onEtfTap(EtfInfo etf) async {
    final notifier = ref.read(myEtfProvider.notifier);
    if (notifier.isRegistered(etf.ticker)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${etf.ticker}는 이미 추가되어 있습니다'),
          backgroundColor: PortfiqTheme.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    EventTracker.instance.track('etf_add', properties: {
      'ticker': etf.ticker,
    });
    EventTracker.instance.track('etf_added', properties: {
      'ticker': etf.ticker,
      'source': 'my_etf',
    });
    await notifier.addEtf(etf.ticker);
    if (mounted) {
      Navigator.of(context).pop(); // 바텀시트 닫기 → 목록에서 즉시 확인
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: PortfiqTheme.positive, size: 18),
              const SizedBox(width: 8),
              Text(
                '${etf.ticker} 추가 완료',
                style: const TextStyle(color: PortfiqTheme.textPrimary),
              ),
            ],
          ),
          backgroundColor: PortfiqTheme.secondaryBg,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myEtfProvider);
    final results = state.searchResults;
    final isSearchEmpty = _searchController.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'ETF 추가',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        // 검색 필드
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: '티커 또는 ETF 이름 검색',
              prefixIcon: const Icon(
                Icons.search,
                color: PortfiqTheme.textSecondary,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: PortfiqTheme.textSecondary,
                        size: 20,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(myEtfProvider.notifier).searchEtfs('');
                        setState(() {});
                      },
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                    )
                  : null,
            ),
          ),
        ),
        // 섹션 라벨
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            isSearchEmpty ? '인기 ETF' : '검색 결과',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        // 결과 리스트
        Expanded(
          child: state.isSearching
              ? const Center(
                  child:
                      CircularProgressIndicator(color: PortfiqTheme.accent),
                )
              : results.isEmpty
                  ? Center(
                      child: Text(
                        '검색 결과가 없습니다',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: PortfiqTheme.divider),
                      itemBuilder: (context, index) {
                        final etf = results[index];
                        final isRegistered =
                            ref.read(myEtfProvider.notifier).isRegistered(
                                  etf.ticker,
                                );
                        return _SearchResultItem(
                          etf: etf,
                          isRegistered: isRegistered,
                          onTap: () => _onEtfTap(etf),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

/// 검색 결과 아이템 위젯.
class _SearchResultItem extends StatelessWidget {
  final EtfInfo etf;
  final bool isRegistered;
  final VoidCallback onTap;

  const _SearchResultItem({
    required this.etf,
    required this.isRegistered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // 티커
            SizedBox(
              width: 60,
              child: Text(
                etf.ticker,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            // 이름
            Expanded(
              child: Text(
                etf.nameKr,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // 카테고리 칩
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: PortfiqTheme.surface,
                borderRadius: BorderRadius.circular(PortfiqTheme.radiusChip),
              ),
              child: Text(
                etf.category,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            if (isRegistered) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                color: PortfiqTheme.positive,
                size: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
