import 'package:ardoise/board_page.dart';
import 'package:ardoise/data/repository.dart';
import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/store.dart';
import 'package:ardoise/theme/app_theme.dart';
import 'package:ardoise/widgets/vault_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ArdoiseStore> open(String path) async {
    final store = ArdoiseStore(
      repository: MemoryRepository(vaultStarterSnapshot()),
      today: DateTime(2026, 10, 13),
    );
    await store.init();
    return store;
  }

  Future<void> pump(WidgetTester tester, VaultGate gate) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildArdoiseTheme(), home: gate));
    await tester.pumpAndSettle();
  }

  testWidgets('un chemin refusé affiche le motif, un bon ouvre le tableau', (
    tester,
  ) async {
    final checked = <String>[];
    await pump(
      tester,
      VaultGate(
        check: (path) async {
          checked.add(path);
          return path == '/bon' ? null : 'Ce dossier n’existe pas.';
        },
        open: open,
      ),
    );

    expect(find.text('Où est ton vault ?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '/mauvais');
    await tester.tap(find.text('Ouvrir ce vault'));
    await tester.pumpAndSettle();
    expect(find.text('Ce dossier n’existe pas.'), findsOneWidget);
    expect(find.byType(BoardPage), findsNothing);

    await tester.enterText(find.byType(TextField), '/bon');
    await tester.tap(find.text('Ouvrir ce vault'));
    await tester.pumpAndSettle();
    expect(checked, ['/mauvais', '/bon']);
    expect(find.byType(BoardPage), findsOneWidget);
    expect(find.text('BDD campus'), findsWidgets);
  });

  testWidgets('un vault déjà retenu s’ouvre sans rien demander', (
    tester,
  ) async {
    await pump(
      tester,
      VaultGate(initialPath: '/bon', check: (_) async => null, open: open),
    );
    expect(find.byType(BoardPage), findsOneWidget);
  });

  testWidgets('un vault retenu mais déplacé redemande le chemin', (
    tester,
  ) async {
    await pump(
      tester,
      VaultGate(
        initialPath: '/parti',
        initialProblem: 'Ce dossier n’existe pas.',
        check: (_) async => 'Ce dossier n’existe pas.',
        open: open,
      ),
    );
    expect(find.byType(BoardPage), findsNothing);
    expect(find.text('Ce dossier n’existe pas.'), findsOneWidget);
    expect(find.text('/parti'), findsOneWidget);
  });
}
