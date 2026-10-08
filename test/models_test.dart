import 'package:ardoise/data/seed.dart';
import 'package:ardoise/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Request _sample({
  String? assigneeId = 'T',
  Set<String> voters = const {'K', 'L'},
}) => Request(
  number: 48,
  projectId: 'echeo',
  title: 'Crash à l’import depuis la galerie',
  description: 'L’app plante sur Android 14.',
  type: RequestType.bug,
  status: RequestStatus.todo,
  requesterId: 'L',
  assigneeId: assigneeId,
  createdAt: DateTime(2026, 10, 7),
  voterIds: voters,
);

void main() {
  test('la référence combine la clé du projet et le numéro', () {
    expect(_sample().reference('ECH'), 'ECH-48');
  });

  test('le nombre de votes est le nombre de votants', () {
    expect(_sample(voters: const {'K', 'L'}).votes, 2);
    expect(_sample(voters: const {}).votes, 0);
    expect(_sample(voters: const {'K'}).votedBy('K'), isTrue);
    expect(_sample(voters: const {'K'}).votedBy('D'), isFalse);
  });

  test('aller-retour JSON : tous les champs survivent', () {
    final before = _sample();
    final after = Request.fromJson(before.toJson());
    expect(after.number, before.number);
    expect(after.title, before.title);
    expect(after.description, before.description);
    expect(after.type, before.type);
    expect(after.status, before.status);
    expect(after.requesterId, before.requesterId);
    expect(after.assigneeId, before.assigneeId);
    expect(after.createdAt, before.createdAt);
    expect(after.voterIds, before.voterIds);
  });

  test('aller-retour JSON : intervenant absent et aucun votant', () {
    final after = Request.fromJson(
      _sample(assigneeId: null, voters: const {}).toJson(),
    );
    expect(after.assigneeId, isNull);
    expect(after.voterIds, isEmpty);
  });

  test('copyWith efface l’intervenant seulement si on le demande', () {
    expect(_sample().copyWith(status: RequestStatus.done).assigneeId, 'T');
    expect(_sample().copyWith(clearAssignee: true).assigneeId, isNull);
    expect(_sample().copyWith(assigneeId: 'I').assigneeId, 'I');
    expect(
      _sample().copyWith(status: RequestStatus.done).status,
      RequestStatus.done,
    );
  });

  test('une demande appartient à un projet, et le JSON le conserve', () {
    final after = Request.fromJson(_sample().toJson());
    expect(after.projectId, 'echeo');
  });

  test('une demande V1 sans projet est reprise dans Échéo', () {
    final v1 = _sample().toJson()..remove('projectId');
    expect(Request.fromJson(v1).projectId, 'echeo');
  });

  test('copyWith ne perd jamais le projet', () {
    expect(_sample().copyWith(status: RequestStatus.done).projectId, 'echeo');
  });

  test('aller-retour JSON de l’instantané', () {
    final before = ArdoiseSnapshot(
      projects: seedProjects,
      requests: seedRequests,
    );
    final after = ArdoiseSnapshot.fromJson(before.toJson());
    expect(after.projects.map((p) => p.id), before.projects.map((p) => p.id));
    expect(after.projects.first.color, before.projects.first.color);
    expect(
      after.requests.map((r) => r.number),
      before.requests.map((r) => r.number),
    );
  });

  test('formats de date français', () {
    expect(formatShortDate(DateTime(2026, 10, 7)), '7 oct.');
    expect(formatShortDate(DateTime(2026, 9, 12)), '12 sept.');
    expect(formatMonthLabel(DateTime(2026, 10, 1)), 'Octobre 2026');
    expect(formatMonthWord(DateTime(2026, 10, 1)), 'octobre');
  });

  test('l’initiale d’une personne est sa première lettre en majuscule', () {
    const p = Person(id: 'I', name: 'Inès', color: Color(0xFFF6E19A));
    expect(p.initial, 'I');
  });

  test('les données d’exemple sont cohérentes', () {
    expect(seedPeople, hasLength(5));
    expect(seedRequests, hasLength(15)); // 13 d’Échéo + 2 de l’Atelier
    // Un vote par personne : jamais plus de votants que de personnes.
    for (final r in seedRequests) {
      expect(r.voterIds.length, lessThanOrEqualTo(seedPeople.length));
      expect(r.votes, r.voterIds.length);
    }
    // Tout identifiant cité existe.
    final ids = seedPeople.map((p) => p.id).toSet();
    for (final r in seedRequests) {
      expect(ids, contains(r.requesterId));
      if (r.assigneeId != null) expect(ids, contains(r.assigneeId));
      expect(ids.containsAll(r.voterIds), isTrue);
    }
    // Tout projet cité existe.
    final projectIds = seedProjects.map((p) => p.id).toSet();
    for (final r in seedRequests) {
      expect(projectIds, contains(r.projectId));
    }
    // Les numéros sont uniques dans chaque projet (plus globalement).
    for (final project in seedProjects) {
      final numbers = seedRequests
          .where((r) => r.projectId == project.id)
          .map((r) => r.number)
          .toList();
      expect(numbers.toSet(), hasLength(numbers.length));
    }
  });
}
