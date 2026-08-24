import 'package:flutter/material.dart';

class RitmoDirectionalIcon extends StatelessWidget {

  const RitmoDirectionalIcon({
    super.key,
    required this.ltrIcon,
    required this.rtlIcon,
    this.size,
    this.color,
  });
  final IconData ltrIcon;
  final IconData rtlIcon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Icon(
      isRtl ? rtlIcon : ltrIcon,
      size: size,
      color: color,
    );
  }
}

class RitmoIcons {
  static Widget back(BuildContext context, {double? size, Color? color}) {
    return Icon(
      Icons.arrow_back_rounded,
      size: size,
      color: color,
    );
  }

  static Widget forward(BuildContext context, {double? size, Color? color}) {
    return Icon(
      Icons.arrow_forward_rounded,
      size: size,
      color: color,
    );
  }

  static Widget chevronBack(BuildContext context, {double? size, Color? color}) {
    return Icon(
      Icons.chevron_left_rounded,
      size: size,
      color: color,
    );
  }

  static Widget chevronForward(BuildContext context, {double? size, Color? color}) {
    return Icon(
      Icons.chevron_right_rounded,
      size: size,
      color: color,
    );
  }
}
