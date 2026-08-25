import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/ai_context_builder.dart';
import 'package:ritmo/core/ai/memory/ai_memory_service.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';

void main() {
  group('C-3: AI Memory Privacy & Sensitivity Detection Tests', () {
    test('isContentSensitive detects medical and menstrual keywords correctly', () {
      expect(AiMemoryService.isContentSensitive('من روز دوم پریود هستم و درد دارم'), isTrue);
      expect(AiMemoryService.isContentSensitive('باید قرص متفورمین را بعد از غذا بخورم'), isTrue);
      expect(AiMemoryService.isContentSensitive('دکتر برای من آزمایش خون تجویز کرد'), isTrue);
      expect(AiMemoryService.isContentSensitive('برنامه ریزی برای آزمون کنکور و مرور فیزیک'), isFalse);
      expect(AiMemoryService.isContentSensitive('ساعت ۶ صبح بیدار شدم و ورزش کردم'), isFalse);
    });

    test('ConsentProfile denySensitive constructor excludes sensitive domains', () {
      const consent = ConsentProfile.denySensitive();
      expect(consent.allowHealth, isFalse);
      expect(consent.allowCycle, isFalse);
      expect(consent.routinesConsent, isTrue);
    });

    test('ConsentProfile with explicit domains enables health and cycle', () {
      const consent = ConsentProfile(
        readableDomains: {
          DataDomain.routines,
          DataDomain.medical,
          DataDomain.cycle,
        },
      );
      expect(consent.allowHealth, isTrue);
      expect(consent.allowCycle, isTrue);
    });
  });
}
