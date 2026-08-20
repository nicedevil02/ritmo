import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// برگهٔ اعتماد (PSN-47) - نواری قابل بازشدن زیر پاسخ دستیار
class ConfidenceLeaflet extends StatefulWidget {
  const ConfidenceLeaflet({
    super.key,
    required this.confidence,
    this.usedFields,
    this.annotations = const [],
  });

  final String confidence;
  final List<String>? usedFields;
  final List<String> annotations;

  @override
  State<ConfidenceLeaflet> createState() => _ConfidenceLeafletState();
}

class _ConfidenceLeafletState extends State<ConfidenceLeaflet>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  static String _label(String c) {
    switch (c) {
      case 'high': return 'اطمینان بالا';
      case 'medium': return 'اطمینان متوسط';
      case 'low': return 'اطمینان پایین';
      default: return 'داده کافی نیست';
    }
  }

  static Color _color(String c, RitmoColors colors) {
    switch (c) {
      case 'high': return colors.success;
      case 'medium': return colors.warning;
      default: return colors.error;
    }
  }

  static IconData _icon(String c) {
    switch (c) {
      case 'high': return CupertinoIcons.checkmark_shield_fill;
      case 'medium': return CupertinoIcons.shield_fill;
      default: return CupertinoIcons.exclamationmark_shield_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accentColor = _color(widget.confidence, colors);
    final hasDetails = (widget.usedFields?.isNotEmpty ?? false) || widget.annotations.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: hasDetails ? _toggle : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.22), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon(widget.confidence), size: 12, color: accentColor),
                  const SizedBox(width: 5),
                  Text(_label(widget.confidence),
                      style: TextStyle(fontSize: 11, color: accentColor, fontFamily: 'Vazirmatn')),
                  if (hasDetails) ...[
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(CupertinoIcons.chevron_left, size: 10, color: accentColor.withValues(alpha: 0.7)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasDetails)
            SizeTransition(
              sizeFactor: _expandAnim,
              axisAlignment: -1,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor.withValues(alpha: 0.15), width: 0.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.usedFields?.isNotEmpty ?? false) ...[
                        Text('داده‌های پشتوانه:',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                                color: colors.textSecondary, fontFamily: 'Vazirmatn')),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: widget.usedFields!.map((f) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colors.borderSubtle, width: 0.8),
                            ),
                            child: Text(f, style: TextStyle(fontSize: 10, color: colors.textSecondary, fontFamily: 'Vazirmatn')),
                          )).toList(),
                        ),
                      ],
                      if (widget.annotations.isNotEmpty) ...[
                        if (widget.usedFields?.isNotEmpty ?? false) const SizedBox(height: 8),
                        Text('یادداشت‌های پردازش:',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                                color: colors.textSecondary, fontFamily: 'Vazirmatn')),
                        const SizedBox(height: 4),
                        ...widget.annotations.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(CupertinoIcons.info_circle, size: 11, color: colors.warning),
                              const SizedBox(width: 4),
                              Flexible(child: Text(a, style: TextStyle(fontSize: 10.5, color: colors.textSecondary, fontFamily: 'Vazirmatn'))),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
