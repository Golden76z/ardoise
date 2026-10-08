import 'package:chantier/board_page.dart';
import 'package:chantier/data/repository.dart';
import 'package:chantier/data/seed.dart';
import 'package:chantier/data/store.dart';
import 'package:chantier/models/models.dart';
import 'package:chantier/theme/app_theme.dart';
import 'package:chantier/theme/tokens.dart';
import 'package:chantier/widgets/board_view.dart';
import 'package:chantier/widgets/request_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ChantierStore> _pump(
  WidgetTester tester, {
  List<Request>? requests,
}) async {
  // Assez large pour que les 4 colonnes tiennent sans défilement.
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final store = ChantierStore(
    repository: MemoryRepository(requests ?? seedRequests),
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
  testWidgets('le tableau s’ouvre sur les 4 colonnes de statut', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Échéo'), findsOneWidget);
    expect(find.text('Octobre 2026'), findsOneWidget);
    for (final s in RequestStatus.values) {
      expect(find.text(s.label), findsWidgets);
    }
    expect(find.byType(RequestCard), findsNWidgets(8));
    expect(find.textContaining('8 demandes en octobre'), findsOneWidget);
  });

  testWidgets('changer de groupement affiche les colonnes par personne', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.widgetWithText(InkWell, 'Intervenant').first);
    await tester.pumpAndSettle();
    expect(find.text('Damien'), findsWidgets);
    expect(find.text('Non assigné'), findsWidgets);
    // La barre des personnes apparaît en mode personne.
    expect(find.text('Intervenants affichés'), findsOneWidget);
  });

  testWidgets('le sélecteur de mois change le contenu', (tester) async {
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Mois précédent'));
    await tester.pumpAndSettle();
    expect(find.text('Septembre 2026'), findsOneWidget);
    expect(find.byType(RequestCard), findsNWidgets(3));
  });

  testWidgets('décocher un type retire ses cartes', (tester) async {
    await _pump(tester);
    await tester.tap(find.textContaining('Bugs'));
    await tester.pumpAndSettle();
    expect(find.byType(RequestCard), findsNWidgets(5));
    // Le compteur de la puce reste à 3 : il ignore le filtre.
    expect(find.textContaining('Bugs'), findsOneWidget);
  });

  testWidgets('un clic sur le titre ouvre le tiroir ; Échap le ferme', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Mode sombre'));
    await tester.pumpAndSettle();
    expect(
      find.text('Un thème sombre qui suit le réglage du système.'),
      findsOneWidget,
    );
    expect(find.text('Demandé par'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Demandé par'), findsNothing);
  });

  testWidgets('le tiroir change le statut et la carte suit', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Crash à l’import depuis la galerie'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'En revue').last);
    await tester.pumpAndSettle();
    expect(store.requestByNumber(48)!.status, RequestStatus.review);
  });

  testWidgets('le tiroir réassigne l’intervenant', (tester) async {
    final store = await _pump(tester);
    await tester.tap(find.text('Crash à l’import depuis la galerie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personne'));
    await tester.pumpAndSettle();
    expect(store.requestByNumber(48)!.assigneeId, isNull);
  });

  testWidgets('voter depuis la carte bascule le vote', (tester) async {
    final store = await _pump(tester);
    final before = store.requestByNumber(48)!.votes;
    await tester.tap(
      find.bySemanticsLabel(
        RegExp('Voter pour Crash à l’import depuis la galerie'),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.requestByNumber(48)!.votes, before + 1);
  });

  testWidgets(
    'création : bouton désactivé sans titre, puis la carte apparaît',
    (tester) async {
      final store = await _pump(tester);
      await tester.tap(find.text('+ Demande'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande'), findsOneWidget);

      await tester.tap(find.text('Créer la demande'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nouvelle demande'),
        findsOneWidget,
        reason: 'titre vide : rien ne se passe',
      );

      await tester.enterText(find.byType(TextField), 'Export en CSV');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer la demande'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande'), findsNothing);
      expect(find.text('Export en CSV'), findsOneWidget);
      expect(store.requestByNumber(58)!.requesterId, store.currentUserId);
    },
  );

  testWidgets(
    'les colonnes se partagent la largeur, puis défilent à l’étroit',
    (tester) async {
      // Large : 4 colonnes doivent dépasser les 250 px minimum.
      await _pump(tester);
      final large = tester.getSize(find.byType(RequestCard).first).width;
      expect(large, greaterThan(T.columnMinWidth - 2 * 12));

      // Étroit : elles retombent à 250 px et le tableau défile.
      tester.view.physicalSize = const Size(700, 1200);
      await tester.pumpAndSettle();
      final narrow = tester.getSize(find.byType(RequestCard).first).width;
      expect(narrow, lessThan(large));
      expect(
        find.descendant(
          of: find.byType(BoardView),
          matching: find.byType(Scrollable),
        ),
        findsWidgets,
        reason: 'le tableau doit défiler horizontalement à l’étroit',
      );
    },
  );

  testWidgets('un mois vide affiche « Rien ce mois-ci » dans chaque colonne', (
    tester,
  ) async {
    await _pump(tester, requests: const []);
    expect(find.text('Rien ce mois-ci'), findsNWidgets(4));
    expect(find.byType(RequestCard), findsNothing);
  });

  testWidgets('un échec d’enregistrement affiche un bandeau', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = MemoryRepository(seedRequests)..failWith = 'disque plein';
    final store = ChantierStore(repository: repo, today: DateTime(2026, 10, 8));
    await store.init();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildChantierTheme(),
        home: BoardPage(store: store),
      ),
    );
    await tester.pumpAndSettle();

    store.setStatus(48, RequestStatus.done);
    await tester.pumpAndSettle();
    expect(find.textContaining('Enregistrement impossible'), findsOneWidget);
  });
}
