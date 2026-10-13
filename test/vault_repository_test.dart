import 'dart:io';

import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/store.dart';
import 'package:ardoise/data/vault_repository.dart';
import 'package:ardoise/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

ArdoiseSnapshot _seed() => ArdoiseSnapshot(
  projects: seedProjects,
  requests: seedRequests,
  people: seedPeople,
  currentUserId: seedCurrentUserId,
);

void main() {
  late Directory vault;

  String path(String relative) =>
      '${vault.path}/$relative'.replaceAll('/', Platform.pathSeparator);
  File note(String relative) => File(path(relative));

  VaultRepository repo() =>
      VaultRepository(vault.path, now: () => DateTime(2026, 10, 13));

  setUp(() async {
    vault = await Directory.systemTemp.createTemp('ardoise_vault_');
    await Directory(path('.obsidian')).create();
    await note('Journal.md').writeAsString('À moi.');
  });

  tearDown(() => vault.delete(recursive: true));

  test('vault neuf : un projet de départ est créé, et rien d’autre n’est touché',
      () async {
    final snapshot = await repo().load();
    expect(snapshot!.projects.single.key, 'PRJ');
    expect(snapshot.requests, isEmpty);
    expect(await note('Ardoise/PRJ/PRJ.md').exists(), isTrue);
    expect(await note('Ardoise/Personnes/Moi.md').exists(), isTrue);
    expect(await note('Journal.md').readAsString(), 'À moi.');
  });

  test('aller-retour par le disque', () async {
    final first = repo();
    await first.load();
    await first.save(_seed());
    expect(await note('Ardoise/ECH/ECH-48.md').exists(), isTrue);
    // Le projet de départ n'est plus dans l'état : sa note part avec lui.
    expect(await note('Ardoise/PRJ/PRJ.md').exists(), isFalse);

    final back = await repo().load();
    expect(back!.projects.map((p) => p.key), ['ECH', 'ATL']);
    expect(back.requests.length, seedRequests.length);
  });

  test('l’app n’écrase pas une modification faite dans Obsidian', () async {
    final app = repo();
    await app.load();
    await app.save(_seed());

    // Pendant ce temps, dans Obsidian : ECH-48 passe en revue.
    final file = note('Ardoise/ECH/ECH-48.md');
    await file.writeAsString(
      (await file.readAsString()).replaceFirst(
        'statut: à faire',
        'statut: en revue',
      ),
    );

    // Dans l'app, on change une autre demande.
    final changed = seedRequests
        .map((r) => r.projectId == 'echeo' && r.number == 51
            ? r.copyWith(status: RequestStatus.done)
            : r)
        .toList();
    await app.save(
      ArdoiseSnapshot(
        projects: seedProjects,
        requests: changed,
        people: seedPeople,
        currentUserId: seedCurrentUserId,
      ),
    );

    expect(await file.readAsString(), contains('statut: en revue'));
    expect(
      await note('Ardoise/ECH/ECH-51.md').readAsString(),
      contains('statut: fait'),
    );
  });

  test('une modification extérieure remonte jusqu’au store', () async {
    final app = repo();
    await app.load();
    await app.save(_seed());
    final store = ArdoiseStore(
      repository: app,
      today: DateTime(2026, 10, 13),
    );
    await store.init();

    final file = note('Ardoise/ECH/ECH-48.md');
    await file.writeAsString(
      (await file.readAsString()).replaceFirst(
        'titre: Crash',
        'titre: Plantage',
      ),
    );
    // Les dates de modification n'ont parfois qu'une seconde de résolution :
    // la taille du fichier, elle, a changé.
    await app.pollNow();
    await Future<void>.delayed(Duration.zero);

    expect(store.requestByNumber(48)!.title, startsWith('Plantage'));
    store.dispose();
  });

  test('une demande créée dans Obsidian est numérotée et renommée', () async {
    final app = repo();
    await app.load();
    await note('Ardoise/PRJ/Import des notes.md').writeAsString(
      '---\nardoise: demande\ntype: idée\n---\nDepuis Pronote.\n',
    );
    final snapshot = await app.load();
    final created = snapshot!.requests.single;
    expect(created.number, 1);
    expect(created.title, 'Import des notes');
    expect(await note('Ardoise/PRJ/Import des notes.md').exists(), isFalse);
    expect(
      await note('Ardoise/PRJ/PRJ-1.md').readAsString(),
      contains('Depuis Pronote.'),
    );
    // Relire ne crée pas de seconde copie.
    expect((await repo().load())!.requests, hasLength(1));
  });

  test('vault illisible : aucune écriture', () async {
    final missing = VaultRepository('${vault.path}/nulle-part');
    expect(await missing.load(), isNull);
    expect(missing.lastLoadError, isNotNull);
    await expectLater(missing.save(_seed()), throwsStateError);
    expect(await Directory('${vault.path}/nulle-part').exists(), isFalse);
  });

  test('choix du vault : il faut un dossier .obsidian', () async {
    expect(await VaultLocation.check(vault.path), isNull);
    expect(await VaultLocation.check('"${vault.path}"'), isNull);
    expect(await VaultLocation.check(''), isNotNull);
    expect(await VaultLocation.check('${vault.path}/absent'), isNotNull);
    final plain = await Directory.systemTemp.createTemp('pas_un_vault_');
    expect(await VaultLocation.check(plain.path), contains('.obsidian'));
    await plain.delete(recursive: true);
  });
}
