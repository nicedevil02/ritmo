import 'package:ritmo/features/worship/logic/worship_engine.dart';
import 'package:ritmo/features/worship/logic/worship_repository.dart';

class WorshipCacheBus {
  static void invalidateAll({DateTime? date, String? dateStr}) {
    if (date != null) {
      WorshipEngine.instance.invalidate(date: date);
    } else if (dateStr != null) {
      WorshipEngine.instance.invalidate(date: DateTime.tryParse(dateStr));
    } else {
      WorshipEngine.instance.invalidate();
    }
    WorshipRepository.instance.invalidateCache();
  }
}
