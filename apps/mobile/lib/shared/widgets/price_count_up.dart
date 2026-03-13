import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Animated number that counts from 0 to [value] on first build.
///
/// Per MASTER.md:
/// - Duration: 800ms
/// - Curve: easeOutExpo
/// - Font: Inter
/// - Accepts prefix (₩), suffix (%), and custom TextStyle.
class PriceCountUp extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final int decimalPlaces;

  /// Whether to use comma separators (e.g. 1,234,567).
  final bool useCommaSeparator;

  const PriceCountUp({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.decimalPlaces = 0,
    this.useCommaSeparator = true,
  });

  @override
  State<PriceCountUp> createState() => _PriceCountUpState();
}

class _PriceCountUpState extends State<PriceCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PortfiqAnimations.priceCountUp,
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(
        parent: _controller,
        curve: PortfiqAnimations.decelerateCurve,
      ),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant PriceCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _animation =
          Tween<double>(begin: _previousValue, end: widget.value).animate(
        CurvedAnimation(
          parent: _controller,
          curve: PortfiqAnimations.decelerateCurve,
        ),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double value) {
    final formatted = value.toStringAsFixed(widget.decimalPlaces);
    if (!widget.useCommaSeparator) return formatted;

    final parts = formatted.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    if (parts.length > 1) {
      return '$intPart.${parts[1]}';
    }
    return intPart;
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (disableAnimations) {
      return Text(
        '${widget.prefix}${_formatNumber(widget.value)}${widget.suffix}',
        style: widget.style ??
            PortfiqTypography.display.copyWith(fontFamily: 'Inter'),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_formatNumber(_animation.value)}${widget.suffix}',
          style: widget.style ??
              PortfiqTypography.display.copyWith(fontFamily: 'Inter'),
        );
      },
    );
  }
}
