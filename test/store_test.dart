import 'package:chantier/data/repository.dart';
import 'package:chantier/data/seed.dart';
import 'package:chantier/data/store.dart';
import 'package:chantier/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un store déjà chargé, calé sur octobre 2026 (le mois des données d'exemple).
Future<ChantierStore> _store({MemoryRepository? repo, DateTime? today}) async {
  final store = ChantierStore(
    repository: repo ?? MemoryRepository(seedRequests),
    today: today ?? DateTime(2026, 10, 8),
  );
  await store.init();
  return store;
}

void main() {
  test('init : les données du dépôt gagnent', () async {
    final store = await _store(repo: MemoryRepository([seedRequests.first]));
    expect(store.loading, isFalse);
    expect(store.visibleRequests, hasLength(1));
  });

  test('init : dépôt vide → données d’exemple', () async {
    final store = await _store(repo: MemoryRepository());
    expect(store.visibleRequests, hasLength(8)); // les 8 demandes d’octobre
  });

  test(
    'init : un dépôt qui lève ne fige pas l’app sur le chargement',
    () async {
      final repo = MemoryRepository(seedRequests)
        ..loadFailsWith = 'stockage inaccessible';
      final store = ChantierStore(
        repository: repo,
        today: DateTime(2026, 10, 8),
      );
      await store.init();
      expect(store.loading, isFalse, reason: 'sinon : indicateur à l’infini');
      expect(store.visibleRequests, hasLength(8), reason: 'données d’exemple');
      expect(store.saveError, contains('stockage inaccessible'));
    },
  );

  test('colonnes par statut : les 4 statuts, cartes au bon endroit', () async {
    final store = await _store();
    expect(store.grouping, BoardGrouping.status);
    expect(store.columns.map((c) => c.title), [
      'À faire',
      'En cours',
      'En revue',
      'Fait',
    ]);
    expect(store.columns.map((c) => c.requests.length), [3, 2, 1, 2]);
    expect(
      store.columns.first.requests.map((r) => r.number),
      containsAll(<int>[48, 51, 53]),
    );
    expect(store.columns.first.dotColor, isNotNull);
    expect(store.columns.first.countAtEnd, isFalse);
  });

  test(
    'colonnes par intervenant : une par personne puis « Non assigné »',
    () async {
      final store = await _store();
      store.setGrouping(BoardGrouping.assignee);
      expect(store.columns.map((c) => c.title), [
        'Damien',
        'Tom',
        'Inès',
        'Léa',
        'Karim',
        'Non assigné',
      ]);
      expect(store.columns.last.isUnassigned, isTrue);
      expect(store.columns.last.requests.map((r) => r.number), [53]);
      expect(
        store.columns.first.requests.map((r) => r.number),
        containsAll(<int>[48, 42, 40]),
      );
      expect(store.columns.first.countAtEnd, isTrue);
      expect(store.columns.first.person?.id, 'D');
    },
  );

  test('colonnes par demandeur : pas de colonne « Non assigné »', () async {
    final store = await _store();
    store.setGrouping(BoardGrouping.requester);
    expect(store.columns.map((c) => c.title), [
      'Damien',
      'Tom',
      'Inès',
      'Léa',
      'Karim',
    ]);
    expect(store.columns.any((c) => c.isUnassigned), isFalse);
  });

  test(
    'masquer une personne retire sa colonne, pas ses cartes du mois',
    () async {
      final store = await _store();
      store.setGrouping(BoardGrouping.assignee);
      final before = store.visibleRequests.length;
      store.togglePerson('D');
      expect(store.isPersonShown('D'), isFalse);
      expect(store.columns.map((c) => c.title), isNot(contains('Damien')));
      expect(store.visibleRequests, hasLength(before));
      store.togglePerson('D');
      expect(store.columns.map((c) => c.title), contains('Damien'));
    },
  );

  test('toutes les personnes masquées : il reste « Non assigné »', () async {
    final store = await _store();
    store.setGrouping(BoardGrouping.assignee);
    for (final p in store.people) {
      store.togglePerson(p.id);
    }
    expect(store.columns.map((c) => c.title), ['Non assigné']);

    store.setGrouping(BoardGrouping.requester);
    expect(store.columns, isEmpty);
  });

  test('filtre de type : le tableau suit, les compteurs non', () async {
    final store = await _store();
    final bugsInMonth = store.countOfType(RequestType.bug);
    expect(bugsInMonth, 3);
    store.toggleType(RequestType.bug);
    expect(store.isTypeActive(RequestType.bug), isFalse);
    expect(
      store.visibleRequests.any((r) => r.type == RequestType.bug),
      isFalse,
    );
    // Le compteur de la puce reste celui du mois, filtre de type ignoré.
    expect(store.countOfType(RequestType.bug), bugsInMonth);
  });

  test(
    'tous les types décochés : tableau vide, colonnes toujours là',
    () async {
      final store = await _store();
      for (final t in RequestType.values) {
        store.toggleType(t);
      }
      expect(store.visibleRequests, isEmpty);
      expect(store.columns, hasLength(4));
      expect(store.columns.every((c) => c.requests.isEmpty), isTrue);
    },
  );

  test('mois vide : rien à afficher et pas de division par zéro', () async {
    final store = await _store(repo: MemoryRepository(const []));
    expect(store.visibleRequests, isEmpty);
    expect(store.countOfType(RequestType.bug), 0);
    expect(store.milestoneProgressPercent, 0);
    expect(store.subtitle, contains('0 demande'));
  });

  test('sélecteur de mois : navigation libre et passage d’année', () async {
    final store = await _store();
    expect(store.visibleRequests, hasLength(8));
    store.shiftMonth(-1);
    expect(store.visibleMonth, DateTime(2026, 9));
    expect(store.visibleRequests, hasLength(3));
    store.shiftMonth(2);
    expect(store.visibleMonth, DateTime(2026, 11));
    expect(store.visibleRequests, hasLength(2));

    final december = await _store(today: DateTime(2026, 12, 15));
    expect(december.visibleMonth, DateTime(2026, 12));
    december.shiftMonth(1);
    expect(december.visibleMonth, DateTime(2027, 1));
    december.shiftMonth(-1);
    expect(december.visibleMonth, DateTime(2026, 12));
  });

  test('vote : bascule, et le compte suit', () async {
    final store = await _store();
    final before = store.requestByNumber(48)!.votes;
    expect(store.requestByNumber(48)!.votedBy(store.currentUserId), isFalse);

    store.toggleVote(48);
    expect(store.requestByNumber(48)!.votes, before + 1);
    expect(store.requestByNumber(48)!.votedBy(store.currentUserId), isTrue);

    store.toggleVote(48);
    expect(store.requestByNumber(48)!.votes, before);
    expect(store.requestByNumber(48)!.votedBy(store.currentUserId), isFalse);
  });

  test('changer le statut déplace la carte de colonne', () async {
    final store = await _store();
    expect(store.columns[3].requests.map((r) => r.number), isNot(contains(48)));
    store.setStatus(48, RequestStatus.done);
    expect(store.columns[0].requests.map((r) => r.number), isNot(contains(48)));
    expect(store.columns[3].requests.map((r) => r.number), contains(48));
  });

  test('réassigner, y compris vers « Personne »', () async {
    final store = await _store();
    store.setGrouping(BoardGrouping.assignee);
    store.setAssignee(48, 'I');
    expect(store.requestByNumber(48)!.assigneeId, 'I');
    store.setAssignee(48, null);
    expect(store.requestByNumber(48)!.assigneeId, isNull);
    expect(store.columns.last.requests.map((r) => r.number), contains(48));
  });

  test(
    'création : numéro suivant, à faire, demandeur = utilisateur courant',
    () async {
      final store = await _store();
      final created = store.createRequest(
        title: '  Export CSV  ',
        type: RequestType.idea,
        assigneeId: 'T',
      );
      expect(created, isNotNull);
      expect(created!.number, 58); // max(57) + 1
      expect(created.title, 'Export CSV');
      expect(created.status, RequestStatus.todo);
      expect(created.requesterId, store.currentUserId);
      expect(created.assigneeId, 'T');
      expect(created.voterIds, isEmpty);
      expect(store.columns.first.requests.first.number, 58);
    },
  );

  test('création : titre vide ou blanc refusé', () async {
    final store = await _store();
    expect(store.createRequest(title: '', type: RequestType.bug), isNull);
    expect(store.createRequest(title: '   ', type: RequestType.bug), isNull);
    expect(store.visibleRequests, hasLength(8));
  });

  test('création : la demande naît dans le mois affiché', () async {
    final store = await _store();
    store.shiftMonth(-1); // septembre
    final created = store.createRequest(
      title: 'Rétro',
      type: RequestType.idea,
    )!;
    expect(created.createdAt.year, 2026);
    expect(created.createdAt.month, 9);
    expect(
      store.visibleRequests.map((r) => r.number),
      contains(created.number),
    );
    store.shiftMonth(1); // octobre : elle n’y est plus
    expect(
      store.visibleRequests.map((r) => r.number),
      isNot(contains(created.number)),
    );
  });

  test('chaque mutation est enregistrée', () async {
    final repo = MemoryRepository(seedRequests);
    final store = await _store(repo: repo);
    store.setStatus(48, RequestStatus.done);
    await Future<void>.delayed(Duration.zero);
    expect(
      repo.stored!.firstWhere((r) => r.number == 48).status,
      RequestStatus.done,
    );
  });

  test('échec d’enregistrement : l’utilisateur est averti', () async {
    final repo = MemoryRepository(seedRequests)..failWith = 'disque plein';
    final store = await _store(repo: repo);
    expect(store.saveError, isNull);
    store.toggleVote(48);
    await Future<void>.delayed(Duration.zero);
    expect(store.saveError, isNotNull);
    expect(store.saveError, contains('disque plein'));

    repo.failWith = null;
    store.toggleVote(48);
    await Future<void>.delayed(Duration.zero);
    expect(store.saveError, isNull);
  });

  test('chaque mutation notifie les écouteurs', () async {
    final store = await _store();
    var notified = 0;
    store.addListener(() => notified++);
    store
      ..setGrouping(BoardGrouping.assignee)
      ..toggleType(RequestType.bug)
      ..togglePerson('D')
      ..shiftMonth(1)
      ..toggleVote(56)
      ..setStatus(56, RequestStatus.doing)
      ..setAssignee(56, 'L');
    expect(notified, greaterThanOrEqualTo(7));
  });

  test('sous-titre : demandes du mois, jalon, progression', () async {
    final store = await _store();
    expect(store.subtitle, '8 demandes en octobre · Jalon v0.4 · 31 %');
    store.shiftMonth(1);
    expect(store.subtitle, startsWith('2 demandes en novembre'));
  });

  test('personById : identifiant inconnu ou nul → null', () async {
    final store = await _store();
    expect(store.personById('D')?.name, 'Damien');
    expect(store.personById(null), isNull);
    expect(store.personById('ZZ'), isNull);
  });
}
