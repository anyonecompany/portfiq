import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../shared/services/api_client.dart';
import '../../shared/tracking/event_tracker.dart';
import '../../shared/widgets/glass_card.dart';

/// 특정 기업이 포함된 ETF 목록 화면.
class CompanyEtfsScreen extends StatefulWidget {
  final String companyTicker;

  const CompanyEtfsScreen({super.key, required this.companyTicker});

  @override
  State<CompanyEtfsScreen> createState() => _CompanyEtfsScreenState();
}

class _CompanyEtfsScreenState extends State<CompanyEtfsScreen> {
  List<_CompanyEtfItem> _etfs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    EventTracker.instance.track('screen_view', properties: {
      'screen': 'company_etfs',
      'company_ticker': widget.companyTicker,
    });
    _fetchCompanyEtfs();
  }

  Future<void> _fetchCompanyEtfs() async {
    try {
      final data =
          await ApiClient.instance.searchByCompany(widget.companyTicker);
      final etfsList = (data['etfs'] as List<dynamic>?) ?? [];
      if (mounted) {
        setState(() {
          _etfs = etfsList
              .map((e) => _CompanyEtfItem(
                    ticker: (e['ticker'] as String?) ?? '',
                    nameKr: (e['name_kr'] as String?) ??
                        (e['name'] as String?) ??
                        '',
                    weight: ((e['weight'] as num?) ?? 0).toDouble(),
                  ))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '데이터를 불러올 수 없습니다';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('${widget.companyTicker}이 포함된 ETF'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: PortfiqTheme.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: PortfiqTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchCompanyEtfs();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_etfs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 48,
                color: PortfiqTheme.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                '이 종목이 포함된 ETF를 찾을 수 없습니다',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _etfs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final etf = _etfs[index];
        return _CompanyEtfCard(
          etf: etf,
          onTap: () {
            EventTracker.instance.track('company_etf_tap', properties: {
              'company': widget.companyTicker,
              'etf_ticker': etf.ticker,
            });
            context.push('/etf/${etf.ticker}');
          },
        );
      },
    );
  }
}

/// 기업 ETF 검색 결과 데이터.
class _CompanyEtfItem {
  final String ticker;
  final String nameKr;
  final double weight;

  const _CompanyEtfItem({
    required this.ticker,
    required this.nameKr,
    required this.weight,
  });
}

/// 기업 ETF 카드 위젯.
class _CompanyEtfCard extends StatelessWidget {
  final _CompanyEtfItem etf;
  final VoidCallback onTap;

  const _CompanyEtfCard({required this.etf, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: GlassCard(
        borderRadius: 12,
        padding: const EdgeInsets.all(PortfiqSpacing.space16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etf.ticker,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontFamily: 'Pretendard',
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    etf.nameKr,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: PortfiqTheme.accent.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(PortfiqTheme.radiusChip),
              ),
              child: Text(
                '${etf.weight.toStringAsFixed(2)}%',
                style: const TextStyle(
                  color: PortfiqTheme.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard',
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: PortfiqTheme.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
