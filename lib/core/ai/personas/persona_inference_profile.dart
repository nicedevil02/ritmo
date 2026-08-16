import 'package:ritmo/core/ai/ai_connection_models.dart';

class PersonaInferenceProfile {
  const PersonaInferenceProfile({
    required this.slot,
    required this.temperature,
    required this.maxTokens,
    required this.stream,
    this.timeoutMs = 15000,
  });

  final AiSlot slot;
  final double temperature;
  final int maxTokens;
  final bool stream;
  final int timeoutMs;

  static PersonaInferenceProfile getProfile(String personaId) {
    switch (personaId) {
      case 'global':
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.4, maxTokens: 700, stream: true);
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
      default:
        // Default to global
        return const PersonaInferenceProfile(slot: AiSlot.assistant, temperature: 0.4, maxTokens: 700, stream: true);
    }
  }
}
