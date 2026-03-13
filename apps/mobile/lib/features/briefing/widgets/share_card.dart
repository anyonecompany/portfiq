import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../feed/feed_models.dart';

/// A beautifully designed card widget specifically for social media sharing.
///
/// This widget is NOT displayed in-app; it is rendered offscreen,
/// captured as a PNG image via [RepaintBoundary], then shared.
/// Optimized for 1080x1350 (4:5 Instagram) aspect ratio.
class ShareCard extends StatelessWidget {
  final BriefingData data;
  final GlobalKey repaintKey;

  const ShareCard({
    super.key,
    required this.data,
    required this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    final isMorning = data.type == BriefingType.morning;
    final accentColor = isMorning
        ? PortfiqTheme.accent
        : PortfiqTheme.warning;
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[now.weekday - 1];
    final dateStr =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')} ($weekday)';

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
              height: 400,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Top: Logo / branding
                  _buildHeader(accentColor),

                  const SizedBox(height: 60),

                  // Date
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: PortfiqTheme.textSecondary,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: PortfiqTheme.textPrimary,
                      height: 1.3,
                      decoration: TextDecoration.none,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Divider
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor,
                          accentColor.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ETF changes or checkpoints
                  if (isMorning)
                    _buildEtfChanges()
                  else
                    _buildCheckpoints(),

                  const Spacer(),

                  // Summary
                  if (data.summary.isNotEmpty) ...[
                    Text(
                      data.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 28,
                        fontWeight: FontWeight.w400,
                        color: PortfiqTheme.textSecondary,
                        height: 1.6,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],

                  // Bottom watermark
                  _buildFooter(accentColor),
                ],
                ),
              ),
            ),

            // Indigo border effect (all edges)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
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

  Widget _buildHeader(Color accentColor) {
    return Row(
      children: [
        // Logo mark
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              'P',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: accentColor,
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
                fontFamily: 'Inter',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: PortfiqTheme.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'AI ETF 브리핑',
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

  Widget _buildEtfChanges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ETF 변동',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: PortfiqTheme.accent,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 28),
        ...data.etfChanges.take(5).map((change) {
          final isPositive = change.changePercent >= 0;
          final color = isPositive ? PortfiqTheme.positive : PortfiqTheme.negative;
          final sign = isPositive ? '+' : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    change.ticker,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: PortfiqTheme.textPrimary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  Text(
                    '$sign${change.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontFamily: 'Inter',
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
        }),
      ],
    );
  }

  Widget _buildCheckpoints() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘 밤 주요 일정',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: PortfiqTheme.warning,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 28),
        ...data.checkpoints.take(4).toList().asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PortfiqTheme.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: PortfiqTheme.warning,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 28,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFFD1D5DB),
                          height: 1.5,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFooter(Color accentColor) {
    return Column(
      children: [
        // Watermark CTA
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.08),
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
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: PortfiqTheme.divider.withValues(alpha: 0.5),
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
                  color: accentColor.withValues(alpha: 0.7),
                  decoration: TextDecoration.none,
                ),
              ),
              const Text(
                'portfiq.com',
                style: TextStyle(
                  fontFamily: 'Inter',
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
