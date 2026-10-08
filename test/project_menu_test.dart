import 'package:ardoise/board_page.dart';
import 'package:ardoise/data/repository.dart';
import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/store.dart';
import 'package:ardoise/models/models.dart';
import 'package:ardoise/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ArdoiseStore> _pump(
  WidgetTester tester, {
  List<Project>? projects,
}) async {
  tester.view.physicalSize = const Size(1600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = ArdoiseStore(
    repository: MemoryRepository(
      ArdoiseSnapshot(
        projects: projects ?? seedProjects,
        requests: seedRequests,
      ),
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

/// Le nom du projet s'affiche aussi en titre de page : on vise la pilule par
/// son libellé d'accessibilité plutôt que par son texte.
Finder _chip(String name) => find.bySemanticsLabel(RegExp('Projet : $name'));

void main() {
  testWidgets('le menu liste les projets et leur nombre de demandes', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(_chip('Échéo'));
    await tester.pumpAndSettle();
    expect(find.text('Atelier'), findsOneWidget);
    expect(find.text('13'), findsWidgets);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('choisir un projet recharge le tableau', (tester) async {
    final store = await _pump(tester);
    await tester.tap(_chip('Échéo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atelier'));
    await tester.pumpAndSettle();
    expect(store.project.id, 'atelier');
    expect(find.text('Choisir le bois'), findsOneWidget);
    expect(find.text('Crash à l’import depuis la galerie'), findsNothing);
  });

  testWidgets('créer un projet : clé en doublon refusée avec un motif', (
    tester,
  ) async {
    final store = await _pump(tester);
    await tester.tap(_chip('Échéo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('project-name')), 'Doublon');
    await tester.enterText(find.byKey(const Key('project-key')), 'ECH');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer le projet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('déjà prise'), findsOneWidget);
    expect(store.projects, hasLength(2));

    await tester.enterText(find.byKey(const Key('project-key')), 'BUR');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer le projet'));
    await tester.pumpAndSettle();
    expect(store.projects, hasLength(3));
    expect(store.projects.last.key, 'BUR');
  });

  testWidgets('la clé est forcée en majuscules et bornée à 5 caractères', (
    tester,
  ) async {
    final store = await _pump(tester);
    await tester.tap(_chip('Échéo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouveau projet'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('project-name')), 'Bureau');
    await tester.enterText(find.byKey(const Key('project-key')), 'burodeluxe');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Créer le projet'));
    await tester.pumpAndSettle();
    expect(store.projects.last.key, 'BUROD');
  });

  testWidgets('supprimer un projet demande confirmation et dit ce qui part', (
    tester,
  ) async {
    final store = await _pump(tester);
    await tester.tap(_chip('Échéo'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Supprimer le projet Atelier'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 demandes'), findsOneWidget);
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(store.projects, hasLength(1));
  });

  testWidgets('le refus de supprimer le dernier projet s’affiche', (
    tester,
  ) async {
    final store = await _pump(tester, projects: [seedProjects.first]);
    await tester.tap(_chip('Échéo'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Supprimer le projet Échéo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('dernier projet'), findsOneWidget);
    expect(store.projects, hasLength(1));
  });
}
