import 'dart:convert';

import 'package:chantier/data/repository.dart';
import 'package:chantier/data/seed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('rien d’enregistré : load rend null', () async {
    expect(await PrefsRepository().load(), isNull);
  });

  test('aller-retour : ce qui est enregistré est relu à l’identique', () async {
    final repo = PrefsRepository();
    await repo.save(seedRequests);
    final loaded = await repo.load();
    expect(loaded, isNotNull);
    expect(loaded!.map((r) => r.number), seedRequests.map((r) => r.number));
    expect(loaded.first.voterIds, seedRequests.first.voterIds);
    expect(loaded.firstWhere((r) => r.number == 53).assigneeId, isNull);
  });

  test('données illisibles : load rend null au lieu de lever', () async {
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

  test('MemoryRepository sert de double pour les tests du store', () async {
    final empty = MemoryRepository();
    expect(await empty.load(), isNull);

    final seeded = MemoryRepository(seedRequests);
    expect(await seeded.load(), hasLength(13));

    await seeded.save(const []);
    expect(await seeded.load(), isEmpty);
  });

  test('le JSON écrit est une liste d’objets', () async {
    final repo = PrefsRepository();
    await repo.save(seedRequests.take(2).toList());
    final prefs = await SharedPreferences.getInstance();
    final decoded = jsonDecode(prefs.getString('chantier.requests.v1')!);
    expect(decoded, isA<List<Object?>>());
    expect((decoded as List).first, isA<Map<String, Object?>>());
  });
}
