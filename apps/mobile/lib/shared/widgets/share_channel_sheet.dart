import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Available share channels.
enum ShareChannel {
  kakao('카카오톡', Icons.chat_bubble_rounded),
  twitter('X (트위터)', Icons.tag),
  instagram('인스타그램 스토리', Icons.camera_alt_outlined),
  other('기타', Icons.share_outlined);

  final String label;
  final IconData icon;

  const ShareChannel(this.label, this.icon);
}

/// Bottom sheet for selecting a share channel.
///
/// Returns the selected [ShareChannel] or `null` if dismissed.
class ShareChannelSheet extends StatelessWidget {
  const ShareChannelSheet({super.key});

  /// Show the share channel selection sheet and return the selected channel.
  static Future<ShareChannel?> show(BuildContext context) {
    return showModalBottomSheet<ShareChannel>(
      context: context,
      backgroundColor: PortfiqTheme.secondaryBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ShareChannelSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                '공유하기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: PortfiqTheme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...ShareChannel.values.map((channel) {
              return _ChannelTile(
                channel: channel,
                onTap: () => Navigator.of(context).pop(channel),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final ShareChannel channel;
  final VoidCallback onTap;

  const _ChannelTile({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PortfiqTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                channel.icon,
                size: 22,
                color: PortfiqTheme.accent,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              channel.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: PortfiqTheme.textPrimary,
              ),
            ),
            const Spacer(),
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
