import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../shared/services/push_service.dart';
import '../../shared/tracking/event_tracker.dart';

/// Step 4: Push Permission — shown as a bottom sheet from Step 3.
class Step4PushPermission extends StatelessWidget {
  const Step4PushPermission({
    super.key,
    required this.onGranted,
    required this.onDenied,
  });

  final VoidCallback onGranted;
  final VoidCallback onDenied;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      decoration: const BoxDecoration(
        color: PortfiqTheme.secondaryBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bell icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: PortfiqTheme.accent.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              size: 32,
              color: PortfiqTheme.accent,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            '매일 아침 8:35,\n간밤 미장 결과를 알려드릴게요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            '내 ETF에 영향을 주는 뉴스가 있을 때만\n알림을 보내드려요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: PortfiqTheme.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 28),

          // CTA: 알림 받기
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                EventTracker.instance.track('push_permission_requested', properties: {
                  'step': 'onboarding',
                });
                // OS 푸시 권한 요청 + FCM 토큰 백엔드 등록
                final granted = await PushService.instance.requestPermission();
                if (granted) {
                  EventTracker.instance.track('push_permission_granted', properties: {
                    'context': 'onboarding',
                  });
                  onGranted();
                } else {
                  EventTracker.instance.track('push_permission_denied', properties: {
                    'context': 'onboarding',
                  });
                  onDenied();
                }
              },
              child: const Text('알림 받기'),
            ),
          ),
          const SizedBox(height: 12),

          // Secondary: 나중에 설정
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: () {
                EventTracker.instance.track('push_permission_denied', properties: {
                  'context': 'onboarding',
                });
                onDenied();
              },
              child: const Text('나중에 설정할게요'),
            ),
          ),
        ],
      ),
    );
  }
}
