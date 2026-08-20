import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/agent_event.dart';
import 'package:ritmo/core/ai/agent/agent_loop_runner.dart';
import 'package:ritmo/core/ai/agent/catalog/agent_tools_initializer.dart';
import 'package:ritmo/core/ai/ai_connection_models.dart';
import 'package:ritmo/core/ai/ai_gateway.dart';
import 'package:ritmo/core/database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class _FakeDb implements Database {
  @override
  bool get isOpen => true;

  @override
  Future<void> close() async {}

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (table == 'app_settings') {
      return [
        {'key': 'ai_memory_enabled', 'value': 'true', 'updatedAt': 123456},
      ];
    }
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    initializeAllAgentTools();
  });

  setUp(() {
    DatabaseHelper.databaseInstance = _FakeDb();
  });

  tearDown(() {
    AIGateway.instance.customChatStreamHandlerForTesting = null;
    DatabaseHelper.databaseInstance = null;
  });

  group('AgentLoopRunner Fake Model ReAct Tests (T47)', () {
    test('executes direct 1-turn response without tool calls', () async {
      AIGateway.instance.customChatStreamHandlerForTesting =
          ({
            required messages,
            slot = AiSlot.assistant,
            temperature,
            maxTokens,
          }) async* {
            yield 'سلام! ';
            yield 'امروز چه کمکی از دست من برمی‌آید؟';
          };

      final events = <AgentEvent>[];
      await for (final event in AgentLoopRunner.instance.runAgent(
        prompt: 'سلام',
        personaId: 'global',
      )) {
        events.add(event);
      }

      final completed = events.whereType<AgentCompletedEvent>().firstOrNull;
      expect(completed, isNotNull);
      expect(
        completed!.finalAnswer,
        contains('سلام! امروز چه کمکی از دست من برمی‌آید؟'),
      );
      expect(completed.steps, isEmpty);
    });

    test(
      'executes multi-turn ReAct cycle (Tool Call -> Execution -> Final Answer)',
      () async {
        var callIndex = 0;
        AIGateway.instance.customChatStreamHandlerForTesting =
            ({
              required messages,
              slot = AiSlot.assistant,
              temperature,
              maxTokens,
            }) async* {
              callIndex++;
              if (callIndex == 1) {
                yield 'اجازه دهید وضعیت حافظه را بررسی کنم:\n';
                yield '<tool_call>{"tool": "recall_facts", "parameters": {"query": "ورزش"}}</tool_call>';
              } else {
                yield 'بر اساس حافظه، شما علاقه‌مند به ورزش هوازی هستید.';
              }
            };

        final events = <AgentEvent>[];
        await for (final event in AgentLoopRunner.instance.runAgent(
          prompt: 'درباره علایق ورزشی من بگو',
          personaId: 'global',
        )) {
          events.add(event);
        }

        expect(callIndex, 2);
        final completed = events.whereType<AgentCompletedEvent>().firstOrNull;
        expect(completed, isNotNull);
        expect(completed!.finalAnswer, contains('بر اساس حافظه'));
        expect(completed.steps.length, greaterThanOrEqualTo(1));
        expect(
          completed.steps.any((s) => s.toolName == 'recall_facts'),
          isTrue,
        );
      },
    );
  });
}
