import 'package:ritmo/core/ai/ai_connection_models.dart';

class PersonaInferenceProfile {
  const PersonaInferenceProfile({
    required this.slot,
    required this.temperature,
    required this.maxTokens,
    required this.stream,
    int? timeoutMs,
  }) : _explicitTimeoutMs = timeoutMs;

  final AiSlot slot;
  final double temperature;
  final int maxTokens;
  final bool stream;
  final int? _explicitTimeoutMs;

  int get timeoutMs => _explicitTimeoutMs ?? (maxTokens * 35).clamp(15000, 45000);

  Duration get timeoutDuration => Duration(milliseconds: timeoutMs);

  /// Explicitly configured persona IDs.
  /// Keep this set in sync with switch cases below!
  static const Set<String> explicitPersonaIds = {
    'global',
    'general',
    'sleep',
    'wellbeing',
    'reflection',
    'goals',
    'konkur',
    'courses',
    'sports',
    'worship',
    'cycle',
    'health',
    'notes',
    'planning',
    'pregnancy',
  };

  static bool hasExplicitProfile(String personaId) => explicitPersonaIds.contains(personaId);

  static PersonaInferenceProfile getProfile(String personaId) {
    switch (personaId) {
      case 'global':
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.4, maxTokens: 700, stream: true);
      case 'general':
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.7, maxTokens: 800, stream: true);
      case 'sleep':
        return const PersonaInferenceProfile(slot: AiSlot.features, temperature: 0.3, maxTokens: 600, stream: true);
      case 'wellbeing':
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.5, maxTokens: 600, stream: true);
      case 'reflection':
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.75, maxTokens: 500, stream: true);
      case 'goals':
        return const PersonaInferenceProfile(slot: AiSlot.features, temperature: 0.4, maxTokens: 900, stream: false);
      case 'konkur':
        return const PersonaInferenceProfile(slot: AiSlot.features, temperature: 0.2, maxTokens: 900, stream: false);
      case 'courses':
        return const PersonaInferenceProfile(slot: AiSlot.features, temperature: 0.3, maxTokens: 700, stream: false);
      case 'sports':
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.5, maxTokens: 700, stream: true);
      case 'worship':
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.45, maxTokens: 600, stream: true);
      case 'cycle':
        return const PersonaInferenceProfile(slot: AiSlot.features, temperature: 0.15, maxTokens: 400, stream: false);
      case 'health':
        return const PersonaInferenceProfile(slot: AiSlot.features, temperature: 0.1, maxTokens: 400, stream: false);
      case 'notes':
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.5, maxTokens: 900, stream: true);
      case 'planning':
        return const PersonaInferenceProfile(slot: AiSlot.features, temperature: 0.3, maxTokens: 950, stream: false);
      case 'pregnancy':
        return const PersonaInferenceProfile(slot: AiSlot.features, temperature: 0.15, maxTokens: 500, stream: true);
      default:
        // Default to global
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.4, maxTokens: 700, stream: true);
    }
  }
}
