import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';

/// 4-tab bottom navigation bar for the app shell.
///
/// Per MASTER.md:
/// - Selected: Indigo color + glow shadow + icon scale 1.1 + visible label
/// - Unselected: muted gray + no glow + icon scale 1.0 + hidden label
/// - Top border: Color(0xFF2D2F3A)
class BottomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PortfiqTheme.primaryBg,
        border: Border(
          top: BorderSide(color: PortfiqTheme.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TabItem(
                icon: LucideIcons.home,
                label: '홈',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _TabItem(
                icon: LucideIcons.barChart2,
                label: '내 ETF',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _TabItem(
                icon: LucideIcons.calendar,
                label: '캘린더',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _TabItem(
                icon: LucideIcons.slidersHorizontal,
                label: '설정',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PortfiqAnimations.normal, // 200ms
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: PortfiqAnimations.defaultCurve,
      ),
    );
    if (widget.isActive) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _TabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.forward();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = PortfiqTheme.accent;
    const inactiveColor = PortfiqTheme.textTertiary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with scale animation and optional glow
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                );
              },
              child: Container(
                decoration: widget.isActive
                    ? const BoxDecoration(
                        boxShadow: [PortfiqShadows.tabGlow],
                      )
                    : null,
                child: Icon(
                  widget.icon,
                  size: 22,
                  color: widget.isActive ? activeColor : inactiveColor,
                ),
              ),
            ),
            const SizedBox(height: PortfiqSpacing.space4),
            // Label: visible only for selected tab with animated appear
            AnimatedOpacity(
              opacity: widget.isActive ? 1.0 : 0.0,
              duration: PortfiqAnimations.normal,
              curve: PortfiqAnimations.defaultCurve,
              child: AnimatedSlide(
                offset: widget.isActive ? Offset.zero : const Offset(0, 0.3),
                duration: PortfiqAnimations.normal,
                curve: PortfiqAnimations.defaultCurve,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isActive ? activeColor : inactiveColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
