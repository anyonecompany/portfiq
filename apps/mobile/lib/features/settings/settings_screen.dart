import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../shared/tracking/event_tracker.dart';
import '../../shared/widgets/glass_card.dart';
import '../my_etf/add_etf_sheet.dart';
import 'settings_provider.dart';

/// Registered ETF for settings display.
class _RegisteredEtf {
  final String ticker;
  final String name;

  const _RegisteredEtf({required this.ticker, required this.name});
}

/// Settings tab screen.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Registered ETFs (mock initial data)
  final List<_RegisteredEtf> _registeredEtfs = [
    const _RegisteredEtf(ticker: 'QQQ', name: 'Invesco QQQ Trust'),
    const _RegisteredEtf(ticker: 'SPY', name: 'SPDR S&P 500 ETF'),
    const _RegisteredEtf(ticker: 'TLT', name: 'iShares 20+ Year Treasury'),
    const _RegisteredEtf(ticker: 'GLD', name: 'SPDR Gold Shares'),
  ];

  @override
  void initState() {
    super.initState();
    EventTracker.instance.track('screen_viewed', properties: {
      'screen_name': 'settings',
    });
  }

  void _removeEtf(int index) {
    final removed = _registeredEtfs[index];
    EventTracker.instance.track('etf_remove', properties: {
      'ticker': removed.ticker,
    });
    EventTracker.instance.track('etf_removed', properties: {
      'ticker': removed.ticker,
      'source': 'settings',
    });
    setState(() {
      _registeredEtfs.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed.ticker} 삭제됨'),
        backgroundColor: PortfiqTheme.secondaryBg,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '되돌리기',
          textColor: PortfiqTheme.accent,
          onPressed: () {
            setState(() {
              _registeredEtfs.insert(index, removed);
            });
          },
        ),
      ),
    );
  }

  void _toggleNotification(String key, bool value) {
    EventTracker.instance.track('notification_toggle', properties: {
      'setting': key,
      'enabled': value,
    });

    // Track specific notification events
    if (key == 'morning_briefing' || key == 'night_checkpoint') {
      final type = key == 'morning_briefing' ? 'morning' : 'night';
      EventTracker.instance.track('notification_time_changed', properties: {
        'type': type,
        'enabled': value,
      });
      if (!value) {
        EventTracker.instance.track('notification_disabled', properties: {
          'type': type,
        });
      }
    } else if (key == 'urgent_news' && !value) {
      EventTracker.instance.track('notification_disabled', properties: {
        'type': 'urgent_news',
      });
    }

    final notifier = ref.read(settingsProvider.notifier);
    switch (key) {
      case 'morning_briefing':
        notifier.setMorningBriefing(value);
        break;
      case 'night_checkpoint':
        notifier.setNightCheckpoint(value);
        break;
      case 'urgent_news':
        notifier.setUrgentNews(value);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortfiqTheme.primaryBg,
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Section 1: ETF 관리
          _buildSectionHeader('ETF 관리'),
          const SizedBox(height: 8),
          _buildEtfSection(),
          const SizedBox(height: 24),

          // Section 2: 알림 설정
          _buildSectionHeader('알림 설정'),
          const SizedBox(height: 8),
          _buildNotificationSection(),
          const SizedBox(height: 24),

          // Section 3: 앱 정보
          _buildSectionHeader('앱 정보'),
          const SizedBox(height: 8),
          _buildAppInfoSection(),
          const SizedBox(height: 16),

          // AI 서비스 고지
          _buildAiDisclosure(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: PortfiqTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildEtfSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PortfiqSpacing.space16),
      child: GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ..._registeredEtfs.asMap().entries.map((entry) {
            final index = entry.key;
            final etf = entry.value;
            return Dismissible(
              key: ValueKey('${etf.ticker}_$index'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _removeEtf(index),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: PortfiqTheme.negative,
                  borderRadius:
                      BorderRadius.circular(PortfiqTheme.radiusCard),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PortfiqTheme.surface,
                        borderRadius:
                            BorderRadius.circular(PortfiqTheme.radiusButton),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        etf.ticker,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: PortfiqTheme.accent,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    title: Text(
                      etf.ticker,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: PortfiqTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      etf.name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: PortfiqTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (index < _registeredEtfs.length - 1)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: PortfiqTheme.divider,
                    ),
                ],
              ),
            );
          }),
          // Add ETF button
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: PortfiqTheme.divider,
          ),
          ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PortfiqTheme.accent.withAlpha(26),
                borderRadius:
                    BorderRadius.circular(PortfiqTheme.radiusButton),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add,
                color: PortfiqTheme.accent,
                size: 20,
              ),
            ),
            title: const Text(
              'ETF 추가',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PortfiqTheme.accent,
              ),
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: PortfiqTheme.secondaryBg,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.75,
                  minChildSize: 0.5,
                  maxChildSize: 0.9,
                  expand: false,
                  builder: (context, scrollController) =>
                      AddEtfSheet(scrollController: scrollController),
                ),
              );
            },
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    final prefs = ref.watch(settingsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PortfiqSpacing.space16),
      child: GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildSwitchTile(
            title: '아침 브리핑 (08:35)',
            value: prefs.morningBriefing,
            onChanged: (v) => _toggleNotification('morning_briefing', v),
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: PortfiqTheme.divider,
          ),
          _buildSwitchTile(
            title: '밤 체크포인트 (22:00)',
            value: prefs.nightCheckpoint,
            onChanged: (v) => _toggleNotification('night_checkpoint', v),
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: PortfiqTheme.divider,
          ),
          _buildSwitchTile(
            title: '긴급 뉴스 알림',
            value: prefs.urgentNews,
            onChanged: (v) => _toggleNotification('urgent_news', v),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: PortfiqTheme.textPrimary,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: PortfiqTheme.accent,
      activeTrackColor: PortfiqTheme.accent.withAlpha(77),
      inactiveThumbColor: PortfiqTheme.textSecondary,
      inactiveTrackColor: PortfiqTheme.surface,
    );
  }

  Widget _buildAppInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PortfiqSpacing.space16),
      child: GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            title: const Text(
              '버전',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: PortfiqTheme.textPrimary,
              ),
            ),
            trailing: const Text(
              '1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: PortfiqTheme.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: PortfiqTheme.divider,
          ),
          ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            title: const Text(
              '이용약관',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: PortfiqTheme.textPrimary,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: PortfiqTheme.textSecondary,
              size: 20,
            ),
            onTap: () => _showLegalDialog('이용약관', _termsText),
          ),
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: PortfiqTheme.divider,
          ),
          ListTile(
            dense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            title: const Text(
              '개인정보처리방침',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: PortfiqTheme.textPrimary,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: PortfiqTheme.textSecondary,
              size: 20,
            ),
            onTap: () => _showLegalDialog('개인정보처리방침', _privacyText),
          ),
        ],
      ),
      ),
    );
  }

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PortfiqTheme.secondaryBg,
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(
                fontSize: 13,
                color: PortfiqTheme.textSecondary,
                height: 1.7,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기', style: TextStyle(color: PortfiqTheme.accent)),
          ),
        ],
      ),
    );
  }

  static const String _termsText = '''
포트픽 이용약관

제1조 (목적)
본 약관은 포트픽(이하 "서비스")의 이용 조건 및 절차에 관한 사항을 규정합니다.

제2조 (서비스 내용)
서비스는 AI 기반 ETF 뉴스 분석 및 브리핑을 제공합니다.

제3조 (면책 조항)
1. 본 서비스에서 제공하는 정보는 투자 조언이 아닌 참고 정보입니다.
2. AI가 생성한 분석 결과의 정확성을 보장하지 않습니다.
3. 투자 결정에 따른 손실에 대해 서비스 제공자는 책임을 지지 않습니다.

제4조 (이용자 의무)
이용자는 서비스를 통해 얻은 정보를 투자의 유일한 근거로 사용하지 않아야 합니다.

제5조 (서비스 변경 및 중단)
서비스 제공자는 사전 공지 후 서비스를 변경하거나 중단할 수 있습니다.

제6조 (개인정보)
개인정보 처리에 관한 사항은 개인정보처리방침에 따릅니다.
''';

  static const String _privacyText = '''
포트픽 개인정보처리방침

1. 수집하는 개인정보
- 디바이스 식별자 (앱 내부 생성)
- 등록 ETF 목록
- 푸시 알림 토큰 (알림 허용 시)

2. 수집 목적
- 맞춤 ETF 브리핑 제공
- 푸시 알림 발송
- 서비스 품질 개선을 위한 사용 통계

3. 보관 기간
- 서비스 이용 기간 중 보관
- 탈퇴 또는 삭제 요청 시 즉시 파기

4. 제3자 제공
- Supabase (데이터 저장): 미국 소재
- Anthropic Claude API (AI 분석): 미국 소재
- 뉴스 분석 시 개인정보는 전달되지 않습니다

5. 개인정보 삭제 요청
앱 설정에서 데이터 초기화 또는 support@portfiq.com으로 요청

6. AI 서비스 고지
본 앱은 AI(Claude)를 활용하여 뉴스를 분석합니다.
AI 분석 결과는 참고 정보이며 투자 조언이 아닙니다.
''';

  Widget _buildAiDisclosure() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PortfiqSpacing.space16),
      child: GlassCard(
        padding: const EdgeInsets.all(PortfiqSpacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'AI 기반 서비스 고지',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PortfiqTheme.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '본 앱의 뉴스 분석 및 브리핑은 AI(Claude)가 생성한 참고 정보이며, '
              '투자 조언이 아닙니다.',
              style: TextStyle(
                fontSize: 12,
                color: PortfiqTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
