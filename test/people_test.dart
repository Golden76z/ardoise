import 'package:ardoise/board_page.dart';
import 'package:ardoise/data/repository.dart';
import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/store.dart';
import 'package:ardoise/models/models.dart';
import 'package:ardoise/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ArdoiseStore> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1800);
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
    MaterialApp(
      theme: buildArdoiseTheme(),
      home: BoardPage(store: store),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// Ouvre le menu de projet puis son entrée « Personnes ».
Future<void> _openPeople(WidgetTester tester) async {
  await tester.tap(find.text('Échéo ▾'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Personnes'));
  await tester.pumpAndSettle();
}

/// Toutes les recherches se portent sur le panneau : les mêmes prénoms
/// s'affichent aussi sur le tableau, derrière.
Finder _inPanel(Finder matching) => find.descendant(
  of: find.byKey(const Key('people-dialog')),
  matching: matching,
);

void main() {
  testWidgets('le panneau tient du petit téléphone au bureau', (tester) async {
    // Le piège récurrent du projet : une mise en page casse sans qu'aucune
    // exception ne remonte. Ici on vérifie au moins qu'elle ne déborde pas,
    // à toutes les largeurs et dans chaque état du panneau.
    for (final largeur in <double>[280, 320, 412, 600, 1440]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(largeur, 1800);
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

      await tester.tap(find.text('Échéo ▾'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'menu à $largeur px');

      await tester.tap(find.text('Personnes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'personnes à $largeur px');

      // En saisie : un champ de plus sur la rangée.
      await tester.tap(_inPanel(find.bySemanticsLabel(RegExp('Renommer Léa'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'renommage à $largeur px');

      // Et avec un refus affiché sous la liste.
      await tester.enterText(find.byKey(const Key('person-name')), 'Tom');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(_inPanel(find.textContaining('porte déjà')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'refus à $largeur px');

      // Refermer : sinon le voile du panneau avale le tap de l'itération
      // suivante.
      await tester.tap(_inPanel(find.text('Fermer')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('le panneau liste les personnes et marque qui je suis', (
    tester,
  ) async {
    await _pump(tester);
    await _openPeople(tester);

    for (final nom in ['Damien', 'Tom', 'Inès', 'Léa', 'Karim']) {
      expect(_inPanel(find.text(nom)), findsOneWidget);
    }
    expect(
      _inPanel(find.text('vous')),
      findsOneWidget,
      reason: 'Damien est l’utilisateur',
    );
  });

  testWidgets('ajouter quelqu’un, et refuser un doublon', (tester) async {
    final store = await _pump(tester);
    await _openPeople(tester);

    await tester.tap(find.text('Nouvelle personne'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('person-name')), 'Tom');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(_inPanel(find.textContaining('porte déjà ce nom')), findsOneWidget);
    expect(store.people, hasLength(5));

    await tester.enterText(find.byKey(const Key('person-name')), 'Zoé');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(store.people.last.name, 'Zoé');
    expect(_inPanel(find.text('Zoé')), findsOneWidget);
  });

  testWidgets('renommer garde les demandes reliées', (tester) async {
    final store = await _pump(tester);
    expect(store.requestByNumber(51)!.assigneeId, 'T');
    await _openPeople(tester);

    await tester.tap(_inPanel(find.bySemanticsLabel(RegExp('Renommer Tom'))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('person-name')), 'Thomas');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_inPanel(find.text('Thomas')), findsOneWidget);
    expect(_inPanel(find.text('Tom')), findsNothing);
    expect(
      store.requestByNumber(51)!.assigneeId,
      'T',
      reason: 'l’identifiant ne bouge pas',
    );
  });

  testWidgets('supprimer une demandeuse est refusé, avec le compte', (
    tester,
  ) async {
    final store = await _pump(tester);
    await _openPeople(tester);

    // Léa a demandé 4 demandes.
    await tester.tap(_inPanel(find.bySemanticsLabel(RegExp('Supprimer Léa'))));
    await tester.pumpAndSettle();
    expect(_inPanel(find.textContaining('4 demandes')), findsOneWidget);
    expect(store.people, hasLength(5));
    expect(_inPanel(find.text('Léa')), findsOneWidget);
  });

  testWidgets('désigner quelqu’un d’autre comme moi', (tester) async {
    final store = await _pump(tester);
    await _openPeople(tester);

    expect(store.currentUserId, 'D');
    // La rangée d'Inès porte « C'est moi » tant qu'elle ne l'est pas.
    final ligneInes = find.ancestor(
      of: _inPanel(find.text('Inès')),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: ligneInes, matching: find.text('C’est moi')).first,
    );
    await tester.pumpAndSettle();
    expect(store.currentUserId, 'I');
  });

  testWidgets('tout effacer dit ce qui part, puis laisse une ardoise nette', (
    tester,
  ) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Échéo ▾'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tout effacer'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 projets'), findsOneWidget);
    expect(find.textContaining('15 demandes'), findsOneWidget);
    expect(find.textContaining('5 personnes'), findsOneWidget);

    await tester.tap(find.widgetWithText(InkWell, 'Tout effacer').last);
    await tester.pumpAndSettle();

    expect(store.projects, hasLength(1));
    expect(store.people, hasLength(1));
    expect(store.visibleRequests, isEmpty);
    expect(find.text('Mon projet'), findsWidgets);
  });
}
