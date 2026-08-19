import 'package:flutter/widgets.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';

/// ظرف ارتفاع-ایمن برای شیت‌هایی که محتوای تمام‌قد دارند (مانند وب‌ویو یا بوم‌های تمام‌عرض) (R-06).
/// برخلاف RitmoSheetScaffold محتوا را اسکرول نمی‌کند، ولی ارتفاع را سقف می‌گیرد
/// و به نوارهای سیستمی و صفحه‌کلید احترام می‌گذارد.
class RitmoFullBleedSheet extends StatelessWidget {
  const RitmoFullBleedSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.9,
    this.minHeightFactor = 0.5,
  });

  final Widget child;
  final double maxHeightFactor;
  final double minHeightFactor;

  @override
  Widget build(BuildContext context) {
    final usableH = RitmoBreakpoints.usableHeight(context);
    final minH = usableH * minHeightFactor;
    final maxH = usableH * maxHeightFactor;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: minH < 0 ? 0 : minH,
            maxHeight: maxH < minH ? minH : maxH,
          ),
          child: child,
        ),
      ),
    );
  }
}
