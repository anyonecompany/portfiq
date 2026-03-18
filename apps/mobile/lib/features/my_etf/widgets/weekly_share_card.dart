import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../etf_models.dart';

/// Share card showing weekly ETF performance for social media sharing.
///
/// Rendered offscreen at 1080x1350 (4:5 Instagram ratio),
/// captured via [RepaintBoundary] and shared as PNG.
class WeeklyShareCard extends StatelessWidget {
  final List<EtfInfo> etfs;
  final GlobalKey repaintKey;

  const WeeklyShareCard({
    super.key,
    required this.etfs,
    required this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final dateRange =
        '${weekStart.month}.${weekStart.day.toString().padLeft(2, '0')}'
        ' - '
        '${now.month}.${now.day.toString().padLeft(2, '0')}';

    // Calculate average performance
    final etfsWithChange = etfs.where((e) => e.changePct != null).toList();
    final avgChange = etfsWithChange.isEmpty
        ? 0.0
        : etfsWithChange.fold<double>(0.0, (sum, e) => sum + e.changePct!) /
            etfsWithChange.length;

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: 1080,
        height: 1350,
        decoration: const BoxDecoration(
          color: PortfiqTheme.primaryBg,
        ),
        child: Stack(
          children: [
            // Subtle gradient overlay at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 350,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      PortfiqTheme.accent.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 72),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Logo
                  _buildHeader(),

                  const SizedBox(height: 48),

                  // Title
                  const Text(
                    '이번 주 내 ETF 수익률',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: PortfiqTheme.textPrimary,
                      height: 1.3,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date range
                  Text(
                    dateRange,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: PortfiqTheme.textSecondary,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Divider
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          PortfiqTheme.accent,
                          PortfiqTheme.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ETF list
                  Expanded(
                    child: Column(
                      children: [
                        ...etfs.take(6).map((etf) => _buildEtfRow(etf)),

                        const Spacer(),

                        // Average performance
                        _buildAverageRow(avgChange),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Footer
                  _buildFooter(),
                ],
              ),
            ),

            // Indigo border
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: PortfiqTheme.accent.withValues(alpha: 0.4),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: PortfiqTheme.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Text(
              'P',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: PortfiqTheme.accent,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PORTFIQ',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: PortfiqTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '주간 수익률 리포트',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: PortfiqTheme.textSecondary,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEtfRow(EtfInfo etf) {
    final changePct = etf.changePct ?? 0.0;
    final isPositive = changePct >= 0;
    final color = isPositive ? PortfiqTheme.positive : PortfiqTheme.negative;
    final sign = isPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: PortfiqTheme.secondaryBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: PortfiqTheme.divider.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Ticker
            SizedBox(
              width: 160,
              child: Text(
                etf.ticker,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: PortfiqTheme.textPrimary,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            // Name (Korean)
            Expanded(
              child: Text(
                etf.nameKr,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 26,
                  fontWeight: FontWeight.w400,
                  color: PortfiqTheme.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Change %
            Text(
              '$sign${changePct.toStringAsFixed(2)}%',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: color,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageRow(double avgChange) {
    final isPositive = avgChange >= 0;
    final color = isPositive ? PortfiqTheme.positive : PortfiqTheme.negative;
    final sign = isPositive ? '+' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: PortfiqTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: PortfiqTheme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '평균 수익률',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 30,
              fontWeight: FontWeight.w600,
              color: PortfiqTheme.textPrimary,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            '$sign${avgChange.toStringAsFixed(2)}%',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: color,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Watermark CTA
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: PortfiqTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              '포트픽으로 내 ETF 브리핑 받기',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: PortfiqTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Bottom bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: PortfiqTheme.divider,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI 분석 by 포트픽',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: PortfiqTheme.accent.withValues(alpha: 0.7),
                  decoration: TextDecoration.none,
                ),
              ),
              const Text(
                'portfiq.com',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: PortfiqTheme.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
