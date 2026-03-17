import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme.dart';
import '../../shared/widgets/glass_card.dart';

/// 지난주 대비 구성종목 변화 위젯.
///
/// [changes] 리스트의 각 항목은 다음 키를 포함한다:
/// - `name`: 기업명
/// - `ticker`: 기업 티커
/// - `old_weight`: 이전 비중 (%)
/// - `new_weight`: 현재 비중 (%)
class EtfHoldingsChangesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> changes;

  const EtfHoldingsChangesWidget({super.key, required this.changes});

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.all(PortfiqSpacing.space20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '지난주 대비 변화',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ...changes.map((change) => _ChangeItem(change: change)),
        ],
      ),
    );
  }
}

class _ChangeItem extends StatelessWidget {
  final Map<String, dynamic> change;

  const _ChangeItem({required this.change});

  @override
  Widget build(BuildContext context) {
    final name = (change['name'] as String?) ?? '';
    final ticker = (change['ticker'] as String?) ?? '';
    final oldWeight = ((change['old_weight'] as num?) ?? 0).toDouble();
    final newWeight = ((change['new_weight'] as num?) ?? 0).toDouble();
    final diff = newWeight - oldWeight;
    final absDiff = diff.abs();

    // Determine color and icon based on change magnitude
    final bool isSignificant = absDiff > 1.0;
    final Color changeColor;
    final IconData arrowIcon;

    if (diff > 0) {
      changeColor =
          isSignificant ? PortfiqTheme.positive : PortfiqTheme.textSecondary;
      arrowIcon = LucideIcons.trendingUp;
    } else if (diff < 0) {
      changeColor =
          isSignificant ? PortfiqTheme.negative : PortfiqTheme.textSecondary;
      arrowIcon = LucideIcons.trendingDown;
    } else {
      changeColor = PortfiqTheme.textSecondary;
      arrowIcon = LucideIcons.minus;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Company info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticker,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontFamily: 'Pretendard',
                      ),
                ),
                if (name.isNotEmpty)
                  Text(
                    name,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Weight change: old% → new%
          Text(
            '${oldWeight.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFamily: 'Pretendard',
                  color: PortfiqTheme.textSecondary,
                ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              LucideIcons.arrowRight,
              size: 14,
              color: PortfiqTheme.textTertiary,
            ),
          ),
          Text(
            '${newWeight.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontFamily: 'Pretendard',
                  color: changeColor,
                  fontWeight: isSignificant ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
          const SizedBox(width: 6),
          Icon(
            arrowIcon,
            size: 16,
            color: changeColor,
          ),
        ],
      ),
    );
  }
}
