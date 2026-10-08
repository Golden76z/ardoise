import 'package:ardoise/data/repository.dart';
import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/store.dart';
import 'package:ardoise/models/models.dart';
import 'package:ardoise/theme/app_theme.dart';
import 'package:ardoise/widgets/board_view.dart';
import 'package:ardoise/widgets/request_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monte `BoardView` seule : la page entière n'apporte rien au glisser-déposer.
/// Le `ListenableBuilder` est indispensable — sans lui le tableau ne se
/// redessine pas après un changement de groupement ni après un dépôt.
Future<ArdoiseStore> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <int>[];
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
      home: Scaffold(
        body: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) =>
                BoardView(store: store, onOpenRequest: opened.add),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// Le titre de colonne, et lui seul : « Inès » ou « Fait » apparaissent aussi
/// sur les cartes (puce de demandeur, puce de statut).
Finder _columnTitle(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.data == label &&
      widget.style == TextStyles.columnTitle,
);

/// Glisse la carte portant `title` jusqu'au centre du titre de `column`.
Future<void> _dragCardTo(
  WidgetTester tester,
  String title,
  String column,
) async {
  final card = find.ancestor(
    of: find.text(title),
    matching: find.byType(RequestCard),
  );
  final from = tester.getCenter(card);
  final to = tester.getCenter(_columnTitle(column));
  final gesture = await tester.startGesture(from);
  // En test `defaultTargetPlatform` vaut `android` : la carte est un
  // `LongPressDraggable`, il faut donc tenir l'appui avant de bouger.
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  // Puis franchir le seuil de déplacement (`kTouchSlop`) avant de viser.
  await gesture.moveTo(Offset(from.dx, from.dy - 30));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('au doigt, la carte ne se saisit qu’à l’appui long', (
    tester,
  ) async {
    // Sans ça, un glissement sur une carte accapare le geste et le tableau
    // devient impossible à faire défiler sur un téléphone — constaté sur un
    // vrai appareil le 08/10.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _pump(tester);
    expect(find.byType(LongPressDraggable<int>), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (w) => w is Draggable<int> && w is! LongPressDraggable<int>,
      ),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('à la souris, le glissement est immédiat', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    await _pump(tester);
    expect(
      find.byWidgetPredicate(
        (w) => w is Draggable<int> && w is! LongPressDraggable<int>,
      ),
      findsWidgets,
    );
    expect(find.byType(LongPressDraggable<int>), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  const cardTitle = 'Crash à l’import depuis la galerie';

  testWidgets('glisser une carte vers « Fait » change son statut', (
    tester,
  ) async {
    final store = await _pump(tester);
    expect(store.requestByNumber(48)!.status, RequestStatus.todo);
    await _dragCardTo(tester, cardTitle, 'Fait');
    expect(store.requestByNumber(48)!.status, RequestStatus.done);
  });

  testWidgets('en mode Intervenant, glisser réassigne', (tester) async {
    final store = await _pump(tester);
    store.setGrouping(BoardGrouping.assignee);
    await tester.pumpAndSettle();
    expect(store.requestByNumber(48)!.assigneeId, 'D');
    await _dragCardTo(tester, cardTitle, 'Inès');
    expect(store.requestByNumber(48)!.assigneeId, 'I');
  });

  testWidgets('glisser vers « Non assigné » retire l’intervenant', (
    tester,
  ) async {
    final store = await _pump(tester);
    store.setGrouping(BoardGrouping.assignee);
    await tester.pumpAndSettle();
    await _dragCardTo(tester, cardTitle, 'Non assigné');
    expect(store.requestByNumber(48)!.assigneeId, isNull);
  });

  testWidgets('déposer sur sa propre colonne n’écrit rien', (tester) async {
    final store = await _pump(tester);
    var notifications = 0;
    store.addListener(() => notifications++);
    await _dragCardTo(tester, cardTitle, 'À faire');
    expect(store.requestByNumber(48)!.status, RequestStatus.todo);
    expect(
      notifications,
      0,
      reason: 'aucun changement = aucune notification, donc aucune écriture',
    );
  });

  testWidgets('en mode Demandeur, les cartes ne se glissent pas', (
    tester,
  ) async {
    final store = await _pump(tester);
    store.setGrouping(BoardGrouping.requester);
    await tester.pumpAndSettle();
    expect(
      find.byType(Draggable<int>),
      findsNothing,
      reason: 'le demandeur est un fait, pas un état',
    );
    expect(store.requestByNumber(48)!.requesterId, 'L');
  });
}
