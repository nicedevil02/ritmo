import 'dart:convert';
import 'package:ritmo/core/ai/brief/domain_brief.dart';
import 'package:ritmo/core/domain/personas/assistant_persona.dart';
import 'package:ritmo/core/domain/commands/ritmo_command.dart';

class PersonaContextProvider {
  static Future<String> getBriefJson(AssistantPersona persona) async {
    final Map<String, Object?> combined = {};

    if (persona.canReadDomain(DataDomain.sleep)) {
      // Stub for sleep brief. In a real scenario, this gets data from SleepEngine
      final dummyBrief = {
        'avgDurationMinutes': 420,
        'avgQuality': 3.5,
        'sleepDebtMinutes': 120,
        'consistencyScore': 65,
        'confidence': 'medium',
      };
      combined['sleep'] = dummyBrief;
    }

    if (persona.canReadDomain(DataDomain.energy)) {
      combined['energy'] = {
        'confidence': 'low',
        'recentTrend': 'stable',
      };
    }

    if (combined.isEmpty) {
      return '{}';
    }

    return jsonEncode(combined);
  }
}

