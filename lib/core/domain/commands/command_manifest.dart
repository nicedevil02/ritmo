import 'package:ritmo/core/domain/commands/ritmo_command_bus.dart';

class CommandManifest {
  static List<Map<String, dynamic>> buildFor({required String personaId}) {
    final bus = RitmoCommandBus.instance;
    final allowedCmds = bus.availableFor(personaId);
    final list = <Map<String, dynamic>>[];
    for (final cmd in allowedCmds) {
      final parameters = <String, Map<String, dynamic>>{};
      cmd.params.forEach((k, v) {
        parameters[k] = v.toToolSchema();
      });
      list.add({
        'id': cmd.id,
        'humanTitle': cmd.humanTitle,
        'description': cmd.humanDescriptionFa,
        'sensitivity': cmd.sensitivity.name,
        'parameters': parameters,
        'requiredParameters': cmd.params.entries
            .where((e) => e.value.required)
            .map((e) => e.key)
            .toList(),
      });
    }
    return list;
  }

  static String asPromptBlock({required String personaId}) {
    final tools = buildFor(personaId: personaId);
    final buffer = StringBuffer();
    buffer.writeln('قابلیت‌ها و فرمان‌های در دسترس دستیار:');
    for (final t in tools) {
      buffer.writeln('- شناسه: ${t['id']} (${t['humanTitle']})');
      buffer.writeln('  توضیح: ${t['description']}');
      final params = t['parameters'] as Map<String, dynamic>;
      if (params.isNotEmpty) {
        buffer.writeln('  پارامترها:');
        params.forEach((name, specMap) {
          final spec = specMap as Map<String, dynamic>;
          final requiredStr = (t['requiredParameters'] as List).contains(name)
              ? 'اجباری'
              : 'اختیاری';
          buffer.writeln(
            '    * $name ($requiredStr): ${spec['description']} (نوع: ${spec['type']})',
          );
        });
      }
    }
    final str = buffer.toString();
    if (str.length > 6000) {
      // Budget rule: if block > 6000 chars, truncate descriptions or remove examples
      final compactBuffer = StringBuffer();
      compactBuffer.writeln('قابلیت‌ها و فرمان‌های در دسترس دستیار:');
      for (final t in tools) {
        compactBuffer.writeln('- ${t['id']} (${t['humanTitle']})');
        final params = t['parameters'] as Map<String, dynamic>;
        if (params.isNotEmpty) {
          params.forEach((name, specMap) {
            final spec = specMap as Map<String, dynamic>;
            final req = (t['requiredParameters'] as List).contains(name)
                ? '*'
                : '';
            compactBuffer.writeln('  $name$req: ${spec['type']}');
          });
        }
      }
      return compactBuffer.toString();
    }
    return str;
  }
}
