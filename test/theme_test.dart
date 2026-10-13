import 'package:ardoise/board_page.dart';
import 'package:ardoise/data/repository.dart';
import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/store.dart';
import 'package:ardoise/theme/app_theme.dart';
import 'package:ardoise/theme/theme_controller.dart';
import 'package:ardoise/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => T.palette = ArdoisePalette.argile);

  test('les couleurs suivent la palette active', () {
    ThemeController.instance.select(ArdoisePalette.menthe);
    expect(T.accent, ArdoisePalette.menthe.accent);
    expect(TextStyles.body.color, ArdoisePalette.menthe.ink);
  });

  test('le choix est retenu, et une palette inconnue retombe sur Argile',
      () async {
    ThemeController.instance.select(ArdoisePalette.lavande);
    await Future<void>.delayed(Duration.zero);
    T.palette = ArdoisePalette.argile;
    await ThemeController.instance.load();
    expect(T.palette.id, 'lavande');

    SharedPreferences.setMockInitialValues({
      ThemeController.preferenceKey: 'disparue',
    });
    await ThemeController.instance.load();
    expect(T.palette.id, 'argile');
  });

  test('chaque palette a un identifiant unique', () {
    final ids = ArdoisePalette.all.map((p) => p.id).toSet();
    expect(ids, hasLength(ArdoisePalette.all.length));
  });

  testWidgets('changer de thème repeint la page', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = ArdoiseStore(
      repository: MemoryRepository(
        ArdoiseSnapshot(projects: seedProjects, requests: seedRequests),
      ),
      today: DateTime(2026, 10, 8),
    );
    await store.init();
    await tester.pumpWidget(
      MaterialApp(theme: buildArdoiseTheme(), home: BoardPage(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Thème de couleurs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ardoise').last);
    await tester.pumpAndSettle();

    expect(T.palette.id, 'ardoise');
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, ArdoisePalette.ardoise.bg);
    expect(tester.takeException(), isNull);
  });
}
