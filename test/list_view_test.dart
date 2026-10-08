import 'package:chantier/board_page.dart';
import 'package:chantier/data/repository.dart';
import 'package:chantier/data/seed.dart';
import 'package:chantier/data/store.dart';
import 'package:chantier/models/models.dart';
import 'package:chantier/theme/app_theme.dart';
import 'package:chantier/widgets/request_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ChantierStore> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = ChantierStore(
    repository: MemoryRepository(
      ChantierSnapshot(projects: seedProjects, requests: seedRequests),
    ),
    today: DateTime(2026, 10, 8),
  );
  await store.init();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildChantierTheme(),
      home: BoardPage(store: store),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('l’onglet Liste montre toutes les demandes, tous mois', (
    tester,
  ) async {
    final store = await _pump(tester);
    expect(find.byType(RequestCard), findsNWidgets(8));
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    expect(store.viewMode, ViewMode.list);
    expect(find.byType(RequestCard), findsNothing, reason: 'plus de tableau');
    // Une demande de septembre, invisible dans le tableau d’octobre.
    expect(find.text('Onboarding en 3 écrans'), findsOneWidget);
    expect(find.textContaining('13 demandes · tous les mois'), findsOneWidget);
  });

  testWidgets('le sélecteur de mois disparaît en vue Liste', (tester) async {
    await _pump(tester);
    expect(find.text('Octobre 2026'), findsOneWidget);
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    expect(find.text('Octobre 2026'), findsNothing);
    expect(
      find.text('Colonnes'),
      findsNothing,
      reason: 'pas de colonnes en liste',
    );
  });

  testWidgets('la recherche filtre, et le vide est annoncé', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('list-search')), 'PDF');
    await tester.pumpAndSettle();
    expect(find.text('Export PDF multi-pages'), findsOneWidget);
    expect(find.text('Mode sombre'), findsNothing);

    await tester.enterText(find.byKey(const Key('list-search')), 'zzzzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune demande'), findsOneWidget);
  });

  testWidgets('changer de projet vide le champ de recherche', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('list-search')), 'PDF');
    await tester.pumpAndSettle();

    // `setCurrentProject` oublie la recherche : le champ doit suivre, sinon il
    // affiche un filtre que le store n’applique plus.
    store.setCurrentProject('atelier');
    await tester.pumpAndSettle();
    expect(store.searchQuery, isEmpty);
    final field = tester.widget<TextField>(
      find.byKey(const Key('list-search')),
    );
    expect(field.controller!.text, isEmpty);
    expect(find.text('Choisir le bois'), findsOneWidget);
  });

  testWidgets('changer de tri réordonne la liste', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus votées'));
    await tester.pumpAndSettle();
    expect(store.listSort, ListSort.votes);
    expect(
      store.listRequests.first.votes,
      greaterThanOrEqualTo(store.listRequests.last.votes),
    );
  });

  testWidgets('les lignes tiennent dans une fenêtre étroite', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    // Un dépassement de `Row` fait échouer le test de lui-même.
    tester.view.physicalSize = const Size(700, 1800);
    await tester.pumpAndSettle();
    expect(find.text('Mode sombre'), findsOneWidget);
  });

  testWidgets('les lignes ne débordent pas sur une fenêtre très étroite', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();

    // Le constat de revue mesurait le débordement à partir de ~500 px.
    for (final width in <double>[520, 480, 440, 380, 320]) {
      tester.view.physicalSize = Size(width, 1400);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'débordement à $width px de large',
      );
    }
  });

  testWidgets('cliquer une ligne ouvre le tiroir', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mode sombre'));
    await tester.pumpAndSettle();
    expect(find.text('Demandé par'), findsOneWidget);
  });
}
