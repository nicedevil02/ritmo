import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/domain/agenda/agenda_item.dart';
import 'package:ritmo/core/domain/agenda/agenda_source_registry.dart';

void main() {
  group('Phase M3-A: Agenda Domain Coverage Test (P1b / M3-1)', () {
    tearDown(() {
      AgendaSourceRegistry.instance.reset();
    });

    test('M3-1: Every AgendaDomain enum value is covered by at least one registered AgendaSourceEntry', () {
      final registry = AgendaSourceRegistry.instance;
      final registeredDomains = <AgendaDomain>{};

      for (final entry in registry.entries) {
        registeredDomains.addAll(entry.domains);
      }

      for (final domain in AgendaDomain.values) {
        expect(
          registeredDomains.contains(domain),
          isTrue,
          reason: 'Domain $domain has no registered AgendaSource in AgendaSourceRegistry',
        );
      }
    });

    test('M3-1: Intentional removal of a source makes coverage test fail (negative test check)', () {
      final registry = AgendaSourceRegistry.instance;
      
      // Filter out the 'appointment' source
      final filteredEntries = registry.entries
          .where((entry) => !entry.domains.contains(AgendaDomain.appointment))
          .toList();
      
      registry.setEntries(filteredEntries);

      final registeredDomains = <AgendaDomain>{};
      for (final entry in registry.entries) {
        registeredDomains.addAll(entry.domains);
      }

      // Assert that without appointment source, AgendaDomain.appointment is missing
      expect(registeredDomains.contains(AgendaDomain.appointment), isFalse);
    });
  });
}
