import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Small chip showing an ETF ticker and its percentage change.
///
/// Per MASTER.md:
/// - Positive: green bg (15% opacity) + green text
/// - Negative: red bg (15% opacity) + red text
/// - Neutral (0): gray bg (15% opacity) + gray text
/// - Font: Inter, 13px, w600
/// - Border radius: 8px
class EtfChip extends StatelessWidget {
  final String ticker;
  final double changePercent;

  const EtfChip({
    super.key,
    required this.ticker,
    required this.changePercent,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String sign;

    if (changePercent > 0) {
      color = PortfiqTheme.positive;
      sign = '+';
    } else if (changePercent < 0) {
      color = PortfiqTheme.negative;
      sign = '';
    } else {
      color = PortfiqTheme.textTertiary;
      sign = '';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PortfiqSpacing.space8,
        vertical: PortfiqSpacing.space4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(PortfiqTheme.radiusChip),
      ),
      child: Text(
        '$ticker $sign${changePercent.toStringAsFixed(1)}%',
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
