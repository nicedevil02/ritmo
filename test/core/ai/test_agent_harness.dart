import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/ai/agent/catalog/agent_tools_initializer.dart';
import 'package:ritmo/core/domain/commands/commands_registry.dart';
import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';
import 'package:ritmo/core/domain/personas/persona_registry.dart';

/// هارنس تست برای برپایی محیط ایجنت و باس فرمان بدون وابستگی به UI
class TestAgentHarness {
  static bool _initialized = false;

  static void setUp() {
    TestWidgetsFlutterBinding.ensureInitialized();
    if (!_initialized) {
      PersonaRegistry.instance.initStandardPersonas();
      RitmoCommandBus.instance.registerAll(buildRegisteredCommands());
      initializeAllAgentTools();
      _initialized = true;
    }
  }
}
