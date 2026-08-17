import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_transcript.dart';

void main() {
  group('AgentTranscript Tests (T09)', () {
    test('trimToBudget preserves system prompt (index 0) and initial user query (index 1)', () {
      final transcript = AgentTranscript(systemPrompt: 'System Instruction Pinned');
      transcript.addUser('Initial User Query Pinned');

      // Add several intermediate turns
      for (var i = 1; i <= 6; i++) {
        transcript.addAssistant('Assistant call $i with extra padding text to increase character count');
        transcript.addBlock('Tool result $i with extra padding text to increase character count');
      }

      expect(transcript.messageCount, 14); // 1 system + 1 user + 12 intermediate messages
      final initialMessages = transcript.toMessages();
      expect(initialMessages[0]['content'], 'System Instruction Pinned');
      expect(initialMessages[1]['content'], 'Initial User Query Pinned');

      // Now trim aggressively to budget of 400 chars, keeping tail = 2
      final didTrim = transcript.trimToBudget(400, keepTail: 2);
      expect(didTrim, isTrue);

      final trimmedMessages = transcript.toMessages();
      // Ensure index 0 and index 1 are completely untouched
      expect(trimmedMessages[0]['role'], 'system');
      expect(trimmedMessages[0]['content'], 'System Instruction Pinned');

      expect(trimmedMessages[1]['role'], 'user');
      expect(trimmedMessages[1]['content'], 'Initial User Query Pinned');

      // Total messages should be at least (2 pinned + keepTail)
      expect(trimmedMessages.length, greaterThanOrEqualTo(4));
    });
  });
}
