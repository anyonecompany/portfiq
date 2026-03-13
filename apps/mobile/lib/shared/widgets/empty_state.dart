import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// A centered empty state widget with icon, message, and optional action button.
///
/// Per MASTER.md: dark bg, glass-style icon container, accent action button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: PortfiqTheme.surfaceCard.withValues(alpha: 0.7),
                shape: BoxShape.circle,
                border: Border.all(
                  color: PortfiqTheme.divider.withValues(alpha: 0.3),
                ),
                boxShadow: const [PortfiqShadows.glassCard],
              ),
              child: Icon(
                icon,
                size: 32,
                color: PortfiqTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PortfiqTypography.body.copyWith(
                color: PortfiqTheme.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
