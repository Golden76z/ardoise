import 'package:ardoise/data/repository.dart';
import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/store.dart';
import 'package:ardoise/models/models.dart';
import 'package:ardoise/theme/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un instantané d'exemple : les deux projets et toutes leurs demandes.
ArdoiseSnapshot _snapshot([List<Request>? requests]) => ArdoiseSnapshot(
  projects: seedProjects,
  requests: requests ?? seedRequests,
);

/// Un store déjà chargé, calé sur octobre 2026 (le mois des données d'exemple).
Future<ArdoiseStore> _store({MemoryRepository? repo, DateTime? today}) async {
  final store = ArdoiseStore(
    repository: repo ?? MemoryRepository(_snapshot()),
    today: today ?? DateTime(2026, 10, 8),
  );
  await store.init();
  return store;
}

void main() {
  test('init : les données du dépôt gagnent', () async {
    final store = await _store(
      repo: MemoryRepository(_snapshot([seedRequests.first])),
    );
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
      final repo = MemoryRepository(_snapshot())
        ..loadFailsWith = 'stockage inaccessible';
      final store = ArdoiseStore(
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
    final store = await _store(repo: MemoryRepository(_snapshot(const [])));
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
    final repo = MemoryRepository(_snapshot());
    final store = await _store(repo: repo);
    store.setStatus(48, RequestStatus.done);
    await Future<void>.delayed(Duration.zero);
    expect(
      repo.stored!.requests.firstWhere((r) => r.number == 48).status,
      RequestStatus.done,
    );
  });

  test('échec d’enregistrement : l’utilisateur est averti', () async {
    final repo = MemoryRepository(_snapshot())..failWith = 'disque plein';
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

  // — Projets —

  test(
    'le projet d’ouverture est le premier, et le tableau s’y restreint',
    () async {
      final store = await _store();
      expect(store.projects, hasLength(2));
      expect(store.project.id, 'echeo');
      expect(store.visibleRequests, hasLength(8));
      expect(
        store.visibleRequests.every((r) => r.projectId == 'echeo'),
        isTrue,
      );
    },
  );

  test('changer de projet change tout ce qui en dépend', () async {
    final store = await _store();
    store.setCurrentProject('atelier');
    expect(store.project.name, 'Atelier');
    expect(store.visibleRequests, hasLength(2));
    expect(store.subtitle, startsWith('2 demandes en octobre'));
    expect(store.countOfType(RequestType.bug), 1);
    // Les colonnes suivent : « Choisir le bois » est à faire, l’établi en cours.
    expect(store.columns[0].requests.map((r) => r.number), [1]);
    expect(store.columns[1].requests.map((r) => r.number), [2]);
  });

  test('la numérotation est propre à chaque projet', () async {
    final store = await _store();
    expect(store.createRequest(title: 'A', type: RequestType.bug)!.number, 58);
    store.setCurrentProject('atelier');
    final created = store.createRequest(title: 'B', type: RequestType.bug)!;
    expect(created.number, 3, reason: 'max(2) + 1, pas max(58) + 1');
    expect(created.projectId, 'atelier');
    expect(created.reference(store.project.key), 'ATL-3');
  });

  test('un projet vide : rien, 0 %, et la numérotation repart à 1', () async {
    final store = await _store();
    expect(
      store.createProject(name: 'Vide', key: 'VID', color: T.project),
      isNull,
    );
    store.setCurrentProject(store.projects.last.id);
    expect(store.visibleRequests, isEmpty);
    expect(store.milestoneProgressPercent, 0);
    expect(store.subtitle, contains('0 demande'));
    expect(store.columns, hasLength(4));
    expect(
      store.createRequest(title: 'Première', type: RequestType.idea)!.number,
      1,
    );
  });

  test(
    'création de projet : clé vide, en doublon, ou trop longue → refusée',
    () async {
      final store = await _store();
      expect(
        store.createProject(name: 'X', key: '', color: T.project),
        isNotNull,
      );
      expect(
        store.createProject(name: 'X', key: '   ', color: T.project),
        isNotNull,
      );
      expect(
        store.createProject(name: 'X', key: 'TROPLONG', color: T.project),
        isNotNull,
      );
      expect(
        store.createProject(name: 'X', key: 'ECH', color: T.project),
        isNotNull,
      );
      expect(
        store.createProject(name: 'X', key: 'ech', color: T.project),
        isNotNull,
        reason: 'la casse ne doit pas créer un doublon déguisé',
      );
      expect(
        store.createProject(name: '', key: 'ZZZ', color: T.project),
        isNotNull,
      );
      expect(
        store.projects,
        hasLength(2),
        reason: 'aucun refus n’a créé de projet',
      );
    },
  );

  test('création de projet : la clé est normalisée en majuscules', () async {
    final store = await _store();
    expect(
      store.createProject(name: '  Bureau ', key: ' bur ', color: T.project),
      isNull,
    );
    final created = store.projects.last;
    expect(created.key, 'BUR');
    expect(created.name, 'Bureau');
  });

  test(
    'supprimer un projet emporte ses demandes et rebascule le courant',
    () async {
      final store = await _store();
      expect(store.requestCountOf('atelier'), 2);
      store.setCurrentProject('atelier');
      expect(store.deleteProject('atelier'), isNull);
      expect(store.projects.map((p) => p.id), ['echeo']);
      expect(store.project.id, 'echeo', reason: 'jamais sans projet courant');
      expect(store.requestCountOf('atelier'), 0);
    },
  );

  test('supprimer le dernier projet est refusé', () async {
    final store = await _store();
    store.deleteProject('atelier');
    expect(store.deleteProject('echeo'), isNotNull);
    expect(store.projects, hasLength(1));
  });

  // — Vue Liste —

  test(
    'deux projets ont chacun leur n°1 : une écriture n’en touche qu’un',
    () async {
      final store = await _store();
      // Atelier a déjà une demande n°1 (« Choisir le bois »).
      expect(
        store.createProject(name: 'Maison', key: 'MAI', color: T.project),
        isNull,
      );
      store.setCurrentProject(store.projects.last.id);
      final collision = store.createRequest(
        title: 'Peindre le mur',
        type: RequestType.idea,
      )!;
      expect(
        collision.number,
        1,
        reason: 'la numérotation repart à 1 par projet',
      );

      // On agit sur la n°1 d’Atelier : celle de Maison ne doit pas bouger.
      store.setCurrentProject('atelier');
      store.setStatus(1, RequestStatus.done);
      store.toggleVote(1);
      store.setAssignee(1, 'K');

      final atelier = store.requestByNumber(1)!;
      expect(atelier.title, 'Choisir le bois');
      expect(atelier.status, RequestStatus.done);
      expect(atelier.assigneeId, 'K');

      store.setCurrentProject(store.projects.last.id);
      final maison = store.requestByNumber(1)!;
      expect(maison.title, 'Peindre le mur');
      expect(
        maison.status,
        RequestStatus.todo,
        reason: 'écriture croisée entre projets',
      );
      expect(maison.votes, 0, reason: 'vote croisé entre projets');
      expect(
        maison.assigneeId,
        isNull,
        reason: 'réassignation croisée entre projets',
      );
    },
  );

  test('requestByNumber ne sort jamais du projet courant', () async {
    final store = await _store();
    expect(store.requestByNumber(1), isNull, reason: 'Échéo n’a pas de n°1');
    store.setCurrentProject('atelier');
    expect(store.requestByNumber(1)!.title, 'Choisir le bois');
    expect(store.requestByNumber(48), isNull, reason: 'ECH-48 est dans Échéo');
  });

  test('un projet inconnu ne devient pas le projet courant', () async {
    final store = await _store();
    store.setCurrentProject('fantome');
    expect(store.currentProjectId, 'echeo');
    expect(store.deleteProject('fantome'), isNotNull);
    expect(store.projects, hasLength(2));
  });

  test('un projet sans jalon n’affiche pas « Jalon » vide', () async {
    final store = await _store();
    store.createProject(name: 'Maison', key: 'MAI', color: T.project);
    store.setCurrentProject(store.projects.last.id);
    expect(store.subtitle, isNot(contains('Jalon')));
    expect(store.subtitle, '0 demande en octobre · 0 %');
    store.setCurrentProject('echeo');
    expect(store.subtitle, contains('Jalon v0.4'));
  });

  test('vue Liste : tous mois confondus, triée, filtrée par type', () async {
    final store = await _store();
    expect(store.viewMode, ViewMode.board);
    store.setViewMode(ViewMode.list);
    // 13 demandes d’Échéo, tous mois : le filtre de mois ne s’applique pas.
    expect(store.listRequests, hasLength(13));

    expect(store.listSort, ListSort.recent);
    final dates = store.listRequests.map((r) => r.createdAt).toList();
    expect(
      dates,
      orderedEquals(List.of(dates)..sort((a, b) => b.compareTo(a))),
    );

    store.setListSort(ListSort.votes);
    final votes = store.listRequests.map((r) => r.votes).toList();
    expect(
      votes,
      orderedEquals(List.of(votes)..sort((a, b) => b.compareTo(a))),
    );

    store.setListSort(ListSort.status);
    expect(store.listRequests.first.status, RequestStatus.todo);
    expect(store.listRequests.last.status, RequestStatus.done);

    store.toggleType(RequestType.bug);
    expect(store.listRequests.any((r) => r.type == RequestType.bug), isFalse);
  });

  test(
    'recherche : titre, description et référence, insensible à la casse',
    () async {
      final store = await _store();
      store.setViewMode(ViewMode.list);

      store.setSearchQuery('PDF');
      expect(store.listRequests.map((r) => r.number), [51]);

      store.setSearchQuery('heic'); // présent dans la description de ECH-48
      expect(store.listRequests.map((r) => r.number), [48]);

      store.setSearchQuery('ech-35');
      expect(store.listRequests.map((r) => r.number), [35]);

      store.setSearchQuery('  ');
      expect(
        store.listRequests,
        hasLength(13),
        reason: 'une requête blanche ne filtre rien',
      );

      store.setSearchQuery('zzzzz');
      expect(store.listRequests, isEmpty);
    },
  );

  test('la recherche ne déborde pas sur les autres projets', () async {
    final store = await _store();
    store.setViewMode(ViewMode.list);
    store.setSearchQuery('bois');
    expect(
      store.listRequests,
      isEmpty,
      reason: '« Choisir le bois » est dans Atelier',
    );
    store.setCurrentProject('atelier');
    expect(
      store.searchQuery,
      isEmpty,
      reason: 'changer de projet remet la recherche à zéro',
    );
    store.setSearchQuery('bois');
    expect(store.listRequests.map((r) => r.number), [1]);
  });
}
