import 'dart:convert';

import 'package:ardoise/data/repository.dart';
import 'package:ardoise/data/seed.dart';
import 'package:ardoise/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ArdoiseSnapshot _seedSnapshot() =>
    ArdoiseSnapshot(projects: seedProjects, requests: seedRequests);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rien d’enregistré : load rend null', () async {
    expect(await PrefsRepository().load(), isNull);
  });

  test('aller-retour : ce qui est enregistré est relu à l’identique', () async {
    final repo = PrefsRepository();
    await repo.save(_seedSnapshot());
    final loaded = await repo.load();
    expect(loaded, isNotNull);
    expect(
      loaded!.requests.map((r) => r.number),
      seedRequests.map((r) => r.number),
    );
    expect(loaded.requests.first.voterIds, seedRequests.first.voterIds);
    expect(
      loaded.requests.firstWhere((r) => r.number == 53).assigneeId,
      isNull,
    );
    expect(loaded.projects.map((p) => p.key), seedProjects.map((p) => p.key));
    expect(loaded.projects.first.color, seedProjects.first.color);
  });

  test('reprise des données V1 : rien n’est perdu', () async {
    // Forme exacte de la V1 : une liste nue de demandes, sans `projectId`.
    final v1 = jsonEncode(
      seedRequests
          .where((r) => r.projectId == 'echeo')
          .map((r) => r.toJson()..remove('projectId'))
          .toList(),
    );
    SharedPreferences.setMockInitialValues({'chantier.requests.v1': v1});

    final snapshot = await PrefsRepository().load();
    expect(snapshot, isNotNull);
    expect(snapshot!.requests, hasLength(13));
    expect(snapshot.requests.every((r) => r.projectId == 'echeo'), isTrue);
    expect(
      snapshot.projects.map((p) => p.id),
      contains('echeo'),
      reason: 'le projet d’accueil doit exister, sinon les demandes sont orphelines',
    );
  });

  test('après reprise, la V2 réécrit sous sa propre clé', () async {
    final v1 = jsonEncode([seedRequests.first.toJson()..remove('projectId')]);
    SharedPreferences.setMockInitialValues({'chantier.requests.v1': v1});
    final repo = PrefsRepository();
    final snapshot = await repo.load();
    await repo.save(snapshot!);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('chantier.snapshot.v2'), isNotNull);
    expect(
      prefs.getString('chantier.requests.v1'),
      isNotNull,
      reason: 'on ne supprime pas la sauvegarde V1 : filet en cas de retour',
    );
  });

  test('instantané illisible : load rend null au lieu de lever', () async {
    for (final garbage in <String>[
      'ceci n’est pas du JSON',
      '{"projects": "pas une liste"}',
      '{"projects": [], "requests": [{"number": 1}]}',
    ]) {
      SharedPreferences.setMockInitialValues({'chantier.snapshot.v2': garbage});
      expect(await PrefsRepository().load(), isNull, reason: garbage);
    }
  });

  test('données V1 illisibles : load rend null au lieu de lever', () async {
    for (final garbage in <String>[
      'ceci n’est pas du JSON',
      '{}',
      '[{"number": "quarante-huit"}]',
      '[{"number": 1, "title": "x"}]', // champs manquants
      '[{"number": 1, "title": "x", "description": "", "type": "chimère", "status": "todo", "requesterId": "D", "assigneeId": null, "createdAt": "2026-10-07T00:00:00.000", "voterIds": []}]',
    ]) {
      SharedPreferences.setMockInitialValues({'chantier.requests.v1': garbage});
      expect(await PrefsRepository().load(), isNull, reason: garbage);
    }
  });

  test(
    'V2 illisible mais V1 intacte : on reprend la V1, pas l’exemple',
    () async {
      final v1 = jsonEncode(
        seedRequests
            .where((r) => r.projectId == 'echeo')
            .take(3)
            .map((r) => r.toJson()..remove('projectId'))
            .toList(),
      );
      SharedPreferences.setMockInitialValues({
        'chantier.requests.v1': v1,
        'chantier.snapshot.v2': '{"projects": [], "requests": [{"number": 1}]}',
      });

      final snapshot = await PrefsRepository().load();
      expect(snapshot, isNotNull);
      expect(
        snapshot!.requests,
        hasLength(3),
        reason: 'le vrai travail de la V1 prime sur les données d’exemple',
      );
      expect(snapshot.requests.every((r) => r.projectId == 'echeo'), isTrue);
    },
  );

  test('V2 illisible et pas de V1 : load rend null', () async {
    SharedPreferences.setMockInitialValues({
      'chantier.snapshot.v2': 'ceci n’est pas du JSON',
    });
    expect(await PrefsRepository().load(), isNull);
  });

  test('MemoryRepository sert de double pour les tests du store', () async {
    final empty = MemoryRepository();
    expect(await empty.load(), isNull);

    final seeded = MemoryRepository(_seedSnapshot());
    expect((await seeded.load())!.requests, hasLength(15));

    await seeded.save(const ArdoiseSnapshot(projects: [], requests: []));
    expect((await seeded.load())!.requests, isEmpty);
  });

  test('le JSON écrit porte les projets et les demandes', () async {
    final repo = PrefsRepository();
    await repo.save(
      ArdoiseSnapshot(
        projects: seedProjects,
        requests: seedRequests.take(2).toList(),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    final decoded = jsonDecode(prefs.getString('chantier.snapshot.v2')!);
    expect(decoded, isA<Map<String, Object?>>());
    final map = decoded as Map<String, Object?>;
    expect(map['projects'], isA<List<Object?>>());
    expect(map['requests'], isA<List<Object?>>());
    expect((map['requests']! as List).first, isA<Map<String, Object?>>());
  });
}
