import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/theme.dart';
import '../../shared/services/api_client.dart';
import '../../shared/tracking/event_tracker.dart';
import 'onboarding_provider.dart';

/// Step 1: ETF Registration — search + popular chips + CTA.
class Step1EtfSelect extends ConsumerStatefulWidget {
  const Step1EtfSelect({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  ConsumerState<Step1EtfSelect> createState() => _Step1EtfSelectState();
}

class _Step1EtfSelectState extends ConsumerState<Step1EtfSelect> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Extended list for search results
  static const List<String> _allEtfs = [
    'QQQ', 'VOO', 'SCHD', 'TQQQ', 'SOXL', 'JEPI',
    'SPY', 'IVV', 'VTI', 'ARKK', 'XLK', 'XLF',
    'SOXX', 'KWEB', 'VGT', 'IEFA', 'EEM', 'GLD',
    'TLT', 'HYG', 'LQD', 'VNQ', 'DIA', 'IWM',
  ];

  List<String> get _filteredEtfs {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toUpperCase();
    return _allEtfs
        .where((etf) => etf.contains(query))
        .where((etf) => !OnboardingNotifier.popularEtfs.contains(etf))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          Text(
            '관심 ETF를\n등록해 주세요',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            '선택한 ETF 기준으로 뉴스를 분석해 드려요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PortfiqTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 24),

          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _searchQuery = value);
              if (value.isNotEmpty) {
                EventTracker.instance.track('etf_search_used', properties: {
                  'query': value,
                });
              }
            },
            style: const TextStyle(color: PortfiqTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'ETF 티커 검색 (예: SPY)',
              prefixIcon: Icon(
                Icons.search,
                color: PortfiqTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Scrollable ETF chips area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search results
                  if (_filteredEtfs.isNotEmpty) ...[
                    Text(
                      '검색 결과',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: PortfiqTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _filteredEtfs.map((ticker) {
                        final selected = state.selectedEtfs.contains(ticker);
                        return _EtfChip(
                          ticker: ticker,
                          selected: selected,
                          onTap: () {
                            EventTracker.instance.track('etf_chip_selected', properties: {
                              'ticker': ticker,
                              'source': 'search_result',
                            });
                            notifier.toggleEtf(ticker);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Popular ETFs
                  Text(
                    '인기 ETF',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: PortfiqTheme.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: OnboardingNotifier.popularEtfs.map((ticker) {
                      final selected = state.selectedEtfs.contains(ticker);
                      return _EtfChip(
                        ticker: ticker,
                        selected: selected,
                        onTap: () {
                          EventTracker.instance.track('etf_chip_selected', properties: {
                            'ticker': ticker,
                            'source': 'popular_chip',
                          });
                          notifier.toggleEtf(ticker);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Selected count
          if (state.selectedEtfs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${state.selectedEtfs.length}개 선택됨',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: PortfiqTheme.accent,
                    ),
              ),
            ),

          // CTA
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: notifier.canProceed
                      ? () async {
                          final tickers = state.selectedEtfs;
                          EventTracker.instance.track(
                            'etf_registered',
                            properties: {
                              'tickers': tickers,
                              'count': tickers.length,
                            },
                          );

                          // Hive에 registered_etfs 저장
                          final box = Hive.box('settings');
                          await box.put('registered_etfs', tickers);

                          // POST /api/v1/etf/register (실패해도 onNext 진행)
                          final deviceId = box.get('device_id') as String?;
                          try {
                            await ApiClient.instance.post(
                              '/api/v1/etf/register',
                              data: {
                                'device_id': deviceId,
                                'tickers': tickers,
                              },
                            );
                          } catch (e) {
                            if (kDebugMode) {
                              print('[Step1EtfSelect] ETF register API failed: $e');
                            }
                          }

                          widget.onNext();
                        }
                      : null,
                  child: const Text('완료'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated ETF selection chip with haptic + scale bounce.
///
/// Per onboarding.md:
/// - Default: #1E2028 bg, #9CA3AF text, pill shape
/// - Selected: #6366F1 @ 20% bg, #6366F1 text, #6366F1 border
/// - Tap: scale bounce 0.95 → 1.02 → 1.0, haptic selectionClick
class _EtfChip extends StatelessWidget {
  const _EtfChip({
    required this.ticker,
    required this.selected,
    required this.onTap,
  });

  final String ticker;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: PortfiqAnimations.normal,
        curve: PortfiqAnimations.springCurve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: selected
              ? PortfiqTheme.accent.withAlpha(51) // 20%
              : PortfiqTheme.tertiaryBg,
          borderRadius: BorderRadius.circular(PortfiqTheme.radiusPill),
          border: Border.all(
            color: selected ? PortfiqTheme.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ticker,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected
                    ? PortfiqTheme.accent
                    : PortfiqTheme.textSecondary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check,
                size: 16,
                color: PortfiqTheme.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
