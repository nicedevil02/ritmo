import 'package:ritmo/core/domain/agenda/agenda_item.dart';

/// بافت مشترکی که یک بار برای کل بازه ساخته میشود و به همهی منابع داده میشود.
class AgendaDayContext {
  const AgendaDayContext({
    required this.date,
    required this.dateStr,
    required this.isToday,
    required this.prayerTimes,
    required this.options,
  });

  final DateTime date;
  final String dateStr;
  final bool isToday;
  final Map<String, String> prayerTimes;
  final AgendaQueryOptions options;

  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isBefore(today);
  }

  bool get isFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.isAfter(today);
  }
}

/// قرارداد واحد هر منبع اجندا.
///
/// قانون: هیچ منبعی حق ندارد داخل [itemsForDate] کوئری بزند.
/// تمام داده باید در [load] یک بار برای کل بازه خوانده شده باشد.
abstract class AgendaSource {
  /// دامنههایی که این منبع تولید میکند.
  Set<AgendaDomain> get domains;

  /// آیا این منبع برای این اجرا فعال است (module gate / رضایت کاربر).
  bool get isEnabled;

  /// آیتمهای این منبع برای یک روز. باید سنکرون و بدون I/O باشد.
  List<AgendaItem> itemsForDate(AgendaDayContext ctx);
}

/// متد کمکی برای یکسانسازی فرمت شناسه‌های اجندا.
String buildAgendaItemId(
  AgendaDomain domain,
  String sourceId,
  String dateStr,
) => '${domain.name}:$sourceId:$dateStr';
