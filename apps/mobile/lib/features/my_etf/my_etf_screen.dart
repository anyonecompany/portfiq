import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/pressable_card.dart';
import '../../shared/widgets/share_channel_sheet.dart';
import '../briefing/share_service.dart';
import 'add_etf_sheet.dart';
import 'etf_models.dart';
import 'my_etf_provider.dart';
import 'widgets/weekly_share_card.dart';

/// 내 포트폴리오 (My ETF) 탭 화면.
class MyEtfScreen extends ConsumerStatefulWidget {
  const MyEtfScreen({super.key});

  @override
  ConsumerState<MyEtfScreen> createState() => _MyEtfScreenState();
}

class _MyEtfScreenState extends ConsumerState<MyEtfScreen>
    with WidgetsBindingObserver {
  final GlobalKey _weeklyShareCardKey = GlobalKey();
  bool _isSharing = false;
  Timer? _autoRefreshTimer;

  static const _autoRefreshInterval = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startAutoRefresh();
    EventTracker.instance.track('screen_view', properties: {
      'screen': 'my_etf',
    });
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _startAutoRefresh();
      // Refresh prices immediately when app comes to foreground
      ref.read(myEtfProvider.notifier).refreshPrices();
    } else if (lifecycleState == AppLifecycleState.paused) {
      _stopAutoRefresh();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      ref.read(myEtfProvider.notifier).refreshPrices();
    });
  }

  void _stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _handleWeeklyShare() async {
    if (_isSharing) return;

    final state = ref.read(myEtfProvider);
    if (state.registeredEtfs.isEmpty) return;

    // Show channel selection
    final channel = await ShareChannelSheet.show(context);
    if (channel == null || !mounted) return;

    setState(() => _isSharing = true);

    EventTracker.instance.track('share_channel_selected', properties: {
      'channel': channel.name,
      'content_type': 'weekly_performance',
    });

    EventTracker.instance.track('weekly_share_generated', properties: {
      'etf_count': state.registeredEtfs.length,
    });

    // Wait for the share card to be laid out
    await Future.delayed(const Duration(milliseconds: 100));

    final success = await ShareService.captureAndShareWithText(
      _weeklyShareCardKey,
      '이번 주 내 ETF 수익률 - 포트픽\n\n다운로드: https://portfiq.com',
      filePrefix: 'portfiq_weekly',
    );

    if (mounted) {
      setState(() => _isSharing = false);

      if (success) {
        EventTracker.instance.track('share_card_shared', properties: {
          'content_type': 'weekly_performance',
          'channel': channel.name,
        });
      }
    }
  }

  void _openAddSheet() {
    EventTracker.instance.track('add_etf_button_tap');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PortfiqTheme.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => AddEtfSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _openCompanySearch() {
    EventTracker.instance.track('company_search_button_tap');
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: PortfiqTheme.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PortfiqTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '기업으로 ETF 찾기',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '종목 티커를 입력하면 해당 기업이 포함된 ETF를 찾아드립니다',
              style: Theme.of(sheetContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: Theme.of(sheetContext).textTheme.bodyMedium,
              decoration: const InputDecoration(
                hintText: '종목 티커 입력 (예: AAPL)',
                prefixIcon: Icon(
                  Icons.search,
                  color: PortfiqTheme.textSecondary,
                ),
              ),
              onSubmitted: (value) {
                final ticker = value.trim().toUpperCase();
                if (ticker.isNotEmpty) {
                  Navigator.of(sheetContext).pop();
                  context.push('/company/$ticker');
                }
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final ticker =
                      controller.text.trim().toUpperCase();
                  if (ticker.isNotEmpty) {
                    Navigator.of(sheetContext).pop();
                    context.push('/company/$ticker');
                  }
                },
                child: const Text('검색'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onCardTap(EtfInfo etf) {
    EventTracker.instance.track('etf_card_tap', properties: {
      'ticker': etf.ticker,
    });
    context.push('/etf/${etf.ticker}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myEtfProvider);

    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      appBar: AppBar(
        title: const Text('내 포트폴리오'),
        actions: [
          IconButton(
            onPressed: _openCompanySearch,
            icon: const Icon(Icons.business, color: PortfiqTheme.textSecondary),
            tooltip: '기업으로 찾기',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add, color: PortfiqTheme.accent),
            tooltip: 'ETF 추가',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
      body: Stack(
        children: [
          state.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: PortfiqTheme.accent),
                )
              : state.registeredEtfs.isEmpty
                  ? _EmptyState(onAdd: _openAddSheet)
                  : RefreshIndicator(
                      color: PortfiqTheme.accent,
                      backgroundColor: PortfiqTheme.secondaryBg,
                      onRefresh: () async {
                        await ref.read(myEtfProvider.notifier).refreshPrices();
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Weekly share button
                          _WeeklyShareButton(
                            isSharing: _isSharing,
                            onTap: _handleWeeklyShare,
                          ),
                          const SizedBox(height: 12),
                          // Last update timestamp + refresh indicator
                          _LastUpdateBar(
                            lastUpdate: state.lastPriceUpdate,
                            isRefreshing: state.isRefreshingPrices,
                          ),
                          const SizedBox(height: 12),
                          // ETF list
                          ...state.registeredEtfs.map((etf) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _EtfCard(
                                etf: etf,
                                onTap: () => _onCardTap(etf),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

          // Offscreen weekly share card for capture
          if (state.registeredEtfs.isNotEmpty)
            Positioned(
              left: -2000,
              top: 0,
              child: WeeklyShareCard(
                etfs: state.registeredEtfs,
                repaintKey: _weeklyShareCardKey,
              ),
            ),
        ],
      ),
    );
  }
}

/// 이번 주 수익률 공유 버튼.
class _WeeklyShareButton extends StatelessWidget {
  final bool isSharing;
  final VoidCallback onTap;

  const _WeeklyShareButton({required this.isSharing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space16),
      child: InkWell(
        onTap: isSharing ? null : onTap,
        borderRadius: BorderRadius.circular(PortfiqTheme.radiusCard),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PortfiqTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: isSharing
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PortfiqTheme.accent,
                        ),
                      ),
                    )
                  : const Icon(
                      LucideIcons.share2,
                      size: 18,
                      color: PortfiqTheme.accent,
                    ),
            ),
            const SizedBox(width: PortfiqSpacing.space12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 주 수익률 공유하기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: PortfiqTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '내 ETF 주간 성과를 공유해보세요',
                    style: TextStyle(
                      fontSize: 13,
                      color: PortfiqTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: PortfiqTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// 마지막 가격 업데이트 시각 표시 바.
class _LastUpdateBar extends StatelessWidget {
  final DateTime? lastUpdate;
  final bool isRefreshing;

  const _LastUpdateBar({required this.lastUpdate, required this.isRefreshing});

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isRefreshing)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: PortfiqTheme.textTertiary,
            ),
          )
        else
          Icon(
            Icons.access_time,
            size: 13,
            color: PortfiqTheme.textTertiary,
          ),
        const SizedBox(width: 6),
        Text(
          isRefreshing
              ? '가격 업데이트 중...'
              : lastUpdate != null
                  ? '마지막 업데이트: ${_formatTimeAgo(lastUpdate!)}'
                  : '가격 정보 없음',
          style: const TextStyle(
            fontSize: 12,
            color: PortfiqTheme.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// 빈 상태 위젯.
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: 64,
              color: PortfiqTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'ETF를 추가해보세요',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: PortfiqTheme.textSecondary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '관심 있는 ETF를 등록하면\n맞춤 뉴스와 브리핑을 받을 수 있어요',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: onAdd,
                child: const Text('ETF 추가하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 개별 ETF 카드 위젯.
class _EtfCard extends StatelessWidget {
  final EtfInfo etf;
  final VoidCallback onTap;

  const _EtfCard({required this.etf, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPositive = (etf.changePct ?? 0) >= 0;
    final changeColor =
        isPositive ? PortfiqTheme.positive : PortfiqTheme.negative;
    final sign = isPositive ? '+' : '';

    return PressableCard(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(PortfiqSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 티커 + 이름
            Row(
              children: [
                Text(
                  etf.ticker,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: PortfiqSpacing.space8),
                Expanded(
                  child: Text(
                    etf.nameKr,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PortfiqSpacing.space12),
            // 가격 + 변동률
            Row(
              children: [
                Text(
                  '\$${etf.currentPrice?.toStringAsFixed(2) ?? '-'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(width: PortfiqSpacing.space12),
                if (etf.changePct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: changeColor.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(PortfiqTheme.radiusChip),
                    ),
                    child: Text(
                      '$sign${etf.changePct!.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: changeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                const Spacer(),
                // 카테고리 칩
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: PortfiqTheme.surface,
                    borderRadius:
                        BorderRadius.circular(PortfiqTheme.radiusChip),
                  ),
                  child: Text(
                    etf.category,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
