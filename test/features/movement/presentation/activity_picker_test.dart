import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritmo/core/theme/ritmo_theme.dart';
import 'package:ritmo/features/movement/application/movement_occurrence_service.dart';
import 'package:ritmo/features/movement/domain/models/movement_activity_kind.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/activity_picker_screen.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/sheets/custom_activity_form_sheet.dart';
import 'package:ritmo/features/movement/presentation/activity_picker/widgets/activity_search_field.dart';
import 'package:ritmo/features/movement/presentation/common/movement_strings.dart';

class FakePickerOccurrenceService extends MovementOccurrenceService {
  FakePickerOccurrenceService(this.kinds);
  List<MovementActivityKind> kinds;

  @override
  Future<List<MovementActivityKind>> getAllActivityKinds({
    bool includeCustom = true,
  }) async {
    return kinds;
  }

  @override
  Future<void> toggleFavoriteActivityKind(String id, [bool? isFavorite]) async {
    final idx = kinds.indexWhere((k) => k.id == id);
    if (idx != -1) {
      kinds[idx] = kinds[idx].copyWith(
        isFavorite: isFavorite ?? !kinds[idx].isFavorite,
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
    final custom = MovementActivityKind(
      id: 'custom_${nameFa.hashCode}',
      nameFa: nameFa,
      family: family,
      icon: icon,
      primaryMetric: primaryMetric,
      isCustom: true,
      createdAt: DateTime.now(),
    );
    kinds.add(custom);
    return custom;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testKinds = [
    MovementActivityKind(
      id: 'kind_walking',
      nameFa: 'پیاده‌روی',
      family: 'walking',
      icon: 'directions_walk',
      primaryMetric: 'duration',
      createdAt: DateTime.now(),
    ),
    MovementActivityKind(
      id: 'kind_running',
      nameFa: 'دویدن',
      family: 'running',
      icon: 'directions_run',
      primaryMetric: 'duration',
      isFavorite: true,
      createdAt: DateTime.now(),
    ),
    MovementActivityKind(
      id: 'kind_cycling',
      nameFa: 'دوچرخه‌سواری',
      family: 'cycling',
      icon: 'directions_bike',
      primaryMetric: 'duration',
      createdAt: DateTime.now(),
    ),
  ];

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: RitmoTheme.build(
        palette: RitmoPalette.jadeNoir,
        brightness: Brightness.dark,
      ),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    );
  }

  group('ActivityPickerScreen Widget Tests', () {
    testWidgets('Renders search field, favorite section, and activity tiles', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakePickerOccurrenceService([...testKinds]);

      await tester.pumpWidget(
        buildTestableWidget(
          ActivityPickerScreen(
            occurrenceService: service,
            intent: ActivityPickerIntent.addToPlan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search field is present
      expect(find.byType(ActivitySearchField), findsOneWidget);

      // New custom activity button is present
      expect(
        find.text(MovementStrings.customActivityNewButton),
        findsOneWidget,
      );

      // Activity tiles are rendered
      expect(find.text('پیاده‌روی', skipOffstage: false), findsWidgets);
      expect(find.text('دوچرخه‌سواری', skipOffstage: false), findsWidgets);
    });

    testWidgets('Search query filters activities and shows search results', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakePickerOccurrenceService([...testKinds]);

      await tester.pumpWidget(
        buildTestableWidget(
          ActivityPickerScreen(
            occurrenceService: service,
            intent: ActivityPickerIntent.addToPlan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search term 'دوچرخه'
      await tester.enterText(find.byType(TextField), 'دوچرخه');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // Running should be hidden, cycling should be visible
      expect(find.text('دوچرخه‌سواری', skipOffstage: false), findsWidgets);
      expect(find.text('پیاده‌روی', skipOffstage: false), findsNothing);
    });

    testWidgets('Tapping on favorite star toggles favorite state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = FakePickerOccurrenceService([...testKinds]);

      await tester.pumpWidget(
        buildTestableWidget(
          ActivityPickerScreen(
            occurrenceService: service,
            intent: ActivityPickerIntent.addToPlan,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find favorite button on walking tile
      final favButtons = find.byIcon(Icons.star_outline_rounded);
      expect(favButtons, findsWidgets);

      await tester.tap(favButtons.first);
      await tester.pumpAndSettle();

      expect(
        service.kinds.firstWhere((k) => k.id == 'kind_walking').isFavorite,
        isTrue,
      );
    });

    testWidgets(
      'CustomActivityFormSheet validates duplicate name and allows submission',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        bool submitted = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: RitmoTheme.build(
              palette: RitmoPalette.jadeNoir,
              brightness: Brightness.dark,
            ),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: CustomActivityFormSheet(
                  existingNames: const ['پیاده‌روی'],
                  onSubmit:
                      ({
                        required nameFa,
                        required family,
                        required primaryMetric,
                        required icon,
                      }) async {
                        submitted = true;
                        return MovementActivityKind(
                          id: 'custom_1',
                          nameFa: nameFa,
                          family: family,
                          icon: icon,
                          primaryMetric: primaryMetric,
                          isCustom: true,
                          createdAt: DateTime.now(),
                        );
                      },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enter duplicate name
        await tester.enterText(find.byType(TextFormField).first, 'پیاده‌روی');
        await tester.pumpAndSettle();

        // Submit button should show duplicate warning
        await tester.ensureVisible(
          find.text(MovementStrings.customActivitySubmit),
        );
        await tester.tap(find.text(MovementStrings.customActivitySubmit));
        await tester.pumpAndSettle();

        expect(
          find.text(MovementStrings.customActivityDuplicateError),
          findsOneWidget,
        );
        expect(submitted, isFalse);

        // Enter unique name
        await tester.enterText(find.byType(TextFormField).first, 'طناب‌زنی');
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.text(MovementStrings.customActivitySubmit),
        );
        await tester.tap(find.text(MovementStrings.customActivitySubmit));
        await tester.pumpAndSettle();

        expect(submitted, isTrue);
      },
    );
  });
}
