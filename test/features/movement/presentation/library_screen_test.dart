import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/library/movement_library_screen.dart';
import 'package:ritmo/features/movement/presentation/library/widgets/filter_chips_bar.dart';
import 'package:ritmo/features/movement/presentation/library/widgets/library_activity_card.dart';

class FakeOccurrenceService extends MovementOccurrenceService {
  final List<MovementActivityKind> _kinds = [
    MovementActivityKind(
      id: 'kind_walking',
      nameFa: 'پیاده‌روی',
      nameEn: 'Walking',
      family: 'walking',
      icon: 'directions_walk',
      primaryMetric: 'duration',
      isCustom: false,
      isFavorite: true,
      createdAt: DateTime.now(),
    ),
    MovementActivityKind(
      id: 'kind_running',
      nameFa: 'دویدن سریع',
      nameEn: 'Running',
      family: 'running',
      icon: 'directions_run',
      primaryMetric: 'distance',
      isCustom: false,
      isFavorite: false,
      createdAt: DateTime.now(),
    ),
    MovementActivityKind(
      id: 'kind_custom_badminton',
      nameFa: 'بدمینتون',
      family: 'team_sports',
      icon: 'sports',
      primaryMetric: 'duration',
      isCustom: true,
      isFavorite: false,
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<MovementActivityKind>> getAllActivityKinds() async {
    return _kinds;
  }

  @override
  Future<void> toggleFavoriteActivityKind(String id, [bool? isFavorite]) async {
    final idx = _kinds.indexWhere((k) => k.id == id);
    if (idx != -1) {
      final current = _kinds[idx];
      _kinds[idx] = current.copyWith(
        isFavorite: isFavorite ?? !current.isFavorite,
      );
    }
  }

  @override
  Future<MovementActivityKind> createCustomActivityKind({
    required String nameFa,
    String? nameEn,
    required String family,
    required String icon,
    required String primaryMetric,
    List<String>? defaultUnits,
  }) async {
    final newKind = MovementActivityKind(
      id: 'kind_custom_${DateTime.now().millisecondsSinceEpoch}',
      nameFa: nameFa,
      nameEn: nameEn,
      family: family,
      icon: icon,
      primaryMetric: primaryMetric,
      isCustom: true,
      createdAt: DateTime.now(),
    );
    _kinds.add(newKind);
    return newKind;
  }
}

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  group('MovementLibraryScreen Tests (Gate 5)', () {
    testWidgets('renders search, filters and activity cards list', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          MovementLibraryScreen(occurrenceService: FakeOccurrenceService()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('کتابخانهٔ فعالیت‌ها'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(FilterChipsBar), findsOneWidget);
      expect(find.byType(LibraryActivityCard), findsNWidgets(3));

      // Test searching
      await tester.enterText(find.byType(TextField), 'سریع');
      await tester.pumpAndSettle();

      expect(find.byType(LibraryActivityCard), findsOneWidget);
      expect(find.text('دویدن سریع'), findsOneWidget);
    });
  });
}
