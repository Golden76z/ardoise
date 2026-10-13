import 'package:ardoise/data/repository.dart';
import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/store.dart';
import 'package:ardoise/data/vault_format.dart';
import 'package:ardoise/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 10, 13, 15);

Future<ArdoiseStore> _store() async {
  final store = ArdoiseStore(
    repository: MemoryRepository(
      ArdoiseSnapshot(
        projects: seedProjects,
        requests: seedRequests,
        people: seedPeople,
        currentUserId: seedCurrentUserId,
      ),
    ),
    today: _today,
  );
  await store.init();
  return store;
}

void main() {
  group('dates en français', () {
    test('formats acceptés', () {
      expect(parseFrenchDate('09/10/2026'), DateTime(2026, 10, 9));
      expect(parseFrenchDate('9/10/26'), DateTime(2026, 10, 9));
      expect(parseFrenchDate('9.10.2026'), DateTime(2026, 10, 9));
      expect(parseFrenchDate(' 2026-10-09 '), DateTime(2026, 10, 9));
    });

    test('date impossible ou illisible : null', () {
      expect(parseFrenchDate('31/02/2026'), isNull);
      expect(parseFrenchDate('demain'), isNull);
      expect(parseFrenchDate(''), isNull);
    });

    test('affichage', () {
      expect(formatNumericDate(DateTime(2026, 10, 9)), '09/10/2026');
    });
  });

  test('en retard : échéance passée et pas faite', () {
    final base = seedRequests.first.copyWith(
      dueDate: DateTime(2026, 10, 12),
      status: RequestStatus.todo,
    );
    expect(base.isOverdue(_today), isTrue);
    expect(base.copyWith(status: RequestStatus.done).isOverdue(_today), isFalse);
    expect(
      base.copyWith(dueDate: DateTime(2026, 10, 13)).isOverdue(_today),
      isFalse,
      reason: 'le jour même n’est pas en retard',
    );
    expect(base.copyWith(clearDueDate: true).isOverdue(_today), isFalse);
  });

  test('store : priorité et échéance se modifient, l’heure est ignorée',
      () async {
    final store = await _store();
    store.setPriority(48, RequestPriority.urgent);
    store.setDueDate(48, DateTime(2026, 10, 20, 17, 30));
    final request = store.requestByNumber(48)!;
    expect(request.priority, RequestPriority.urgent);
    expect(request.dueDate, DateTime(2026, 10, 20));
    store.setDueDate(48, null);
    expect(store.requestByNumber(48)!.dueDate, isNull);
  });

  test('création avec priorité et échéance', () async {
    final store = await _store();
    final created = store.createRequest(
      title: 'Demandes PAP',
      type: RequestType.feature,
      priority: RequestPriority.high,
      dueDate: DateTime(2026, 10, 30),
    )!;
    expect(created.priority, RequestPriority.high);
    expect(created.dueDate, DateTime(2026, 10, 30));
  });

  test('tri par priorité puis par échéance', () async {
    final store = await _store();
    store
      ..setPriority(48, RequestPriority.urgent)
      ..setDueDate(51, DateTime(2026, 10, 1))
      ..setDueDate(48, DateTime(2026, 11, 1))
      ..setListSort(ListSort.priority);
    expect(store.listRequests.first.number, 48);

    store.setListSort(ListSort.due);
    expect(store.listRequests.first.number, 51);
    expect(store.listRequests[1].number, 48);
    expect(store.listRequests.last.dueDate, isNull);
  });

  test('JSON : anciennes données sans priorité ni échéance', () {
    final json = seedRequests.first.toJson()
      ..remove('priority')
      ..remove('dueDate');
    final back = Request.fromJson(json);
    expect(back.priority, RequestPriority.medium);
    expect(back.dueDate, isNull);
  });

  test('vault : aller-retour, et valeurs saisies dans Obsidian', () {
    final snapshot = ArdoiseSnapshot(
      projects: seedProjects,
      requests: [
        seedRequests.first.copyWith(
          priority: RequestPriority.urgent,
          dueDate: DateTime(2026, 9, 23),
        ),
      ],
      people: seedPeople,
      currentUserId: seedCurrentUserId,
    );
    final files = renderVault(snapshot);
    final path = files.keys.firstWhere((k) => k.endsWith('-48.md'));
    final note = parseNote(files[path]!);
    expect(note.properties['priorite'], 'urgente');
    expect(note.properties['echeance'], '2026-09-23');

    final back = decodeVault(files, now: _today).snapshot!.requests.single;
    expect(back.priority, RequestPriority.urgent);
    expect(back.dueDate, DateTime(2026, 9, 23));

    files[path] = files[path]!
        .replaceFirst('priorite: urgente', 'priorite: Haute')
        .replaceFirst('echeance: 2026-09-23', 'echeance: 2026-10-30');
    final edited = decodeVault(files, now: _today).snapshot!.requests.single;
    expect(edited.priority, RequestPriority.high);
    expect(edited.dueDate, DateTime(2026, 10, 30));

    files[path] = files[path]!.replaceFirst('priorite: Haute', 'priorite: max');
    final contents = decodeVault(files, now: _today);
    expect(contents.problems.single, contains('priorité'));
  });
}
