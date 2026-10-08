import 'package:ardoise/board_page.dart';
import 'package:ardoise/data/repository.dart';
import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/store.dart';
import 'package:ardoise/models/models.dart';
import 'package:ardoise/theme/app_theme.dart';
import 'package:ardoise/theme/tokens.dart';
import 'package:ardoise/widgets/list_view.dart';
import 'package:ardoise/widgets/nav_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monte l'app à une largeur donnée, en pixels logiques.
Future<ArdoiseStore> _pumpAt(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 1600);
  addTearDown(tester.view.reset);

  final store = ArdoiseStore(
    repository: MemoryRepository(
      ArdoiseSnapshot(projects: seedProjects, requests: seedRequests),
    ),
    today: DateTime(2026, 10, 8),
  );
  await store.init();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildArdoiseTheme(),
      home: BoardPage(store: store),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  // Largeurs réelles : un petit téléphone, un téléphone courant, une tablette
  // en portrait, un bureau. Le piège de ce projet est qu'une mise en page
  // casse sans qu'aucune exception ne soit levée, d'où les assertions de
  // structure en plus de l'absence de débordement.
  const largeurs = <double>[320, 380, 412, 600, 820, 1440];

  testWidgets('aucun débordement, du petit téléphone au bureau', (
    tester,
  ) async {
    for (final largeur in largeurs) {
      await _pumpAt(tester, largeur);
      expect(tester.takeException(), isNull, reason: 'tableau à $largeur px');

      await tester.tap(find.text('Liste'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'liste à $largeur px');
    }
  });

  testWidgets('au téléphone, la navigation tient sur une ligne', (
    tester,
  ) async {
    await _pumpAt(tester, 412);
    // « Votes » est inerte : au téléphone elle coûterait de la largeur pour rien.
    expect(find.text('Votes'), findsNothing);
    // Le bouton de création perd son libellé mais garde son nom accessible.
    expect(find.text('+ Demande'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Nouvelle demande')), findsOneWidget);
    // Une seule rangée : le logo décoratif part, et le sélecteur de mois
    // descend dans l'en-tête — c'est le prix de la ligne unique.
    expect(find.text('A'), findsNothing, reason: 'logo décoratif au téléphone');
    expect(
      find.descendant(
        of: find.byType(NavPill),
        matching: find.byType(MonthPicker),
      ),
      findsNothing,
    );
    expect(find.byType(MonthPicker), findsOneWidget, reason: 'dans l’en-tête');
    // Les éléments de la nav tiennent sur une seule ligne.
    final navItems = <Finder>[
      find.descendant(of: find.byType(NavPill), matching: find.text('Échéo ▾')),
      find.descendant(of: find.byType(NavPill), matching: find.text('Tableau')),
      find.descendant(of: find.byType(NavPill), matching: find.text('Liste')),
    ];
    final centres = navItems.map((f) => tester.getCenter(f).dy).toList();
    for (final c in centres) {
      expect(c, closeTo(centres.first, 2), reason: 'tous sur la même ligne');
    }

    // Le libellé du segment disparaît, pas ses options.
    expect(find.text('Colonnes'), findsNothing);
    for (final g in BoardGrouping.values) {
      expect(find.text(g.label), findsOneWidget);
    }
  });

  testWidgets('un nom de projet long ne fait pas déborder la navigation', (
    tester,
  ) async {
    // `createProject` borne la clé à 5 caractères mais pas le nom : au
    // téléphone la rangée haute est un `Row` figé, et sans ellipsis elle
    // débordait en dur dès qu'un projet portait un nom un peu long.
    for (final largeur in <double>[280, 320, 412]) {
      final store = await _pumpAt(tester, largeur);
      expect(
        store.createProject(
          name: 'Refonte du site vitrine et du back-office',
          key: 'LONG',
          color: T.project,
        ),
        isNull,
      );
      store.setCurrentProject(store.projects.last.id);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'nom long à $largeur px');
    }
  });

  testWidgets('le libellé du segment reste au lecteur d’écran', (tester) async {
    // Au téléphone le libellé visible disparaît : sans lui en sémantique,
    // « Plus récentes » ne dit pas de quoi il s'agit.
    await _pumpAt(tester, 412);
    expect(find.text('Colonnes'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Colonnes')), findsOneWidget);
  });

  testWidgets('au bureau, la navigation garde tout', (tester) async {
    await _pumpAt(tester, 1440);
    expect(find.text('Votes'), findsOneWidget);
    expect(find.text('+ Demande'), findsOneWidget);
    expect(find.text('Colonnes'), findsOneWidget);
  });

  testWidgets('le titre du projet rétrécit au téléphone', (tester) async {
    await _pumpAt(tester, 1440);
    final large = tester.widget<Text>(find.text('Échéo')).style!.fontSize;

    await _pumpAt(tester, 412);
    final etroit = tester.widget<Text>(find.text('Échéo')).style!.fontSize;

    expect(etroit, lessThan(large!));
    expect(etroit, 32);
  });

  testWidgets('à l’étroit, le titre d’une ligne de liste passe en premier', (
    tester,
  ) async {
    await _pumpAt(tester, 412);
    await tester.tap(find.text('Liste'));
    await tester.pumpAndSettle();

    final titre = find.descendant(
      of: find.byType(RequestListView),
      matching: find.text('Widget écran d’accueil'),
    );
    final reference = find.descendant(
      of: find.byType(RequestListView),
      matching: find.textContaining('ECH-57'),
    );
    expect(titre, findsOneWidget);
    // Le titre est au-dessus de la référence, et commence au bord gauche.
    expect(
      tester.getTopLeft(titre).dy,
      lessThan(tester.getTopLeft(reference).dy),
    );
    expect(
      tester.getTopLeft(titre).dx,
      lessThan(tester.getTopLeft(reference).dx + 1),
    );
  });
}
