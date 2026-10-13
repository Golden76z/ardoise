import 'package:ardoise/data/seed.dart';
import 'package:ardoise/data/vault_format.dart';
import 'package:ardoise/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

ArdoiseSnapshot _seed() => ArdoiseSnapshot(
  projects: seedProjects,
  requests: seedRequests,
  people: seedPeople,
  currentUserId: seedCurrentUserId,
);

final _now = DateTime(2026, 10, 13, 9);

ArdoiseSnapshot _roundTrip(ArdoiseSnapshot snapshot) =>
    decodeVault(renderVault(snapshot), now: _now).snapshot!;

void main() {
  group('note', () {
    test('frontmatter : scalaires, listes, guillemets, liens', () {
      final note = parseNote('''---
ardoise: demande
numero: 12
titre: "Crash : import HEIC"
type: bug
intervenant:
votes:
  - "[[Tom]]"
  - "[[Léa]]"
tags: [a, "b, c"]
cree: 2026-10-07T14:30:00
---
Le corps.
''');
      expect(note.properties['numero'], 12);
      expect(note.properties['titre'], 'Crash : import HEIC');
      expect(note.properties['intervenant'], isNull);
      expect(note.properties['votes'], ['[[Tom]]', '[[Léa]]']);
      expect(note.properties['tags'], ['a', 'b, c']);
      expect(note.properties['cree'], '2026-10-07T14:30:00');
      expect(note.body.trim(), 'Le corps.');
    });

    test('écrire puis relire rend les mêmes propriétés', () {
      final text = writeNote(
        const Note({
          'titre': 'Deux-points : et # dièse',
          'n': 3,
          'vide': null,
          'liste': ['[[Inès]]'],
          'chiffres': '404',
          'oui': 'true',
        }, 'Texte\n'),
      );
      final back = parseNote(text);
      expect(back.properties['titre'], 'Deux-points : et # dièse');
      expect(back.properties['n'], 3);
      expect(back.properties['vide'], isNull);
      expect(back.properties['liste'], ['[[Inès]]']);
      // Une chaîne qui ressemble à un nombre ou un booléen reste une chaîne.
      expect(back.properties['chiffres'], '404');
      expect(back.properties['oui'], 'true');
    });

    test('sameNote ignore la mise en forme d’Obsidian', () {
      const ours = '---\ntitre: "Titre: x"\nvotes:\n  - "[[Tom]]"\n---\nCorps\n';
      const obsidian = "---\ntitre: 'Titre: x'\nvotes: [\"[[Tom]]\"]\n---\n\nCorps";
      expect(sameNote(ours, obsidian), isTrue);
      expect(sameNote(ours, ours.replaceFirst('Corps', 'Autre')), isFalse);
    });

    test('un nom de fichier valable partout', () {
      expect(fileSafe('Léa / Tom : "x"'), 'Léa - Tom - -x-');
      expect(fileSafe('fin.'), 'fin');
      expect(fileSafe('   '), 'sans-nom');
    });

    test('liens Obsidian', () {
      expect(linkTarget('[[Dana]]'), 'Dana');
      expect(linkTarget('[[Personnes/Dana|D.]]'), 'Dana');
      expect(linkTarget('Dana'), 'Dana');
      expect(linkTarget(''), isNull);
    });
  });

  group('vault', () {
    test('aller-retour : l’état relu est celui écrit', () {
      final back = _roundTrip(_seed());
      expect(back.projects.map((p) => p.key), seedProjects.map((p) => p.key));
      expect(back.projects.first.color, seedProjects.first.color);
      expect(back.projects.first.milestoneName, 'v0.4');
      expect(back.people!.map((p) => p.id), seedPeople.map((p) => p.id));
      expect(back.people!.first.color, seedPeople.first.color);
      expect(back.currentUserId, seedCurrentUserId);
      expect(back.requests.length, seedRequests.length);
      for (final original in seedRequests) {
        final r = back.requests.singleWhere(
          (x) => x.projectId == original.projectId && x.number == original.number,
        );
        expect(r.title, original.title);
        expect(r.description, original.description);
        expect(r.type, original.type);
        expect(r.status, original.status);
        expect(r.requesterId, original.requesterId);
        expect(r.assigneeId, original.assigneeId);
        expect(r.createdAt, original.createdAt);
      }
    });

    test('la disposition : une note par demande, rangée par projet', () {
      final files = renderVault(_seed());
      expect(files.keys, contains('Ardoise/Ardoise.md'));
      expect(files.keys, contains('Ardoise/Personnes/Dana.md'));
      expect(files.keys, contains('Ardoise/ECH/ECH.md'));
      expect(files.keys, contains('Ardoise/ECH/ECH-48.md'));
      final note = parseNote(files['Ardoise/ECH/ECH-48.md']!);
      expect(note.properties['statut'], 'à faire');
      expect(note.properties['type'], 'bug');
      expect(note.properties['demandeur'], '[[Léa]]');
      expect(note.properties['intervenant'], '[[Dana]]');
    });

    test('vault vide : pas d’état', () {
      expect(decodeVault(const {}, now: _now).snapshot, isNull);
    });

    test('les propriétés et le corps ajoutés dans Obsidian sont gardés', () {
      final first = renderVault(_seed());
      final edited = {
        ...first,
        'Ardoise/ECH/ECH-48.md': first['Ardoise/ECH/ECH-48.md']!.replaceFirst(
          'ardoise: demande',
          'ardoise: demande\ntags:\n  - urgent',
        ),
        'Ardoise/ECH/ECH.md': '${first['Ardoise/ECH/ECH.md']!}\nMes notes.\n',
      };
      final again = renderVault(_seed(), existing: edited);
      expect(
        parseNote(again['Ardoise/ECH/ECH-48.md']!).properties['tags'],
        ['urgent'],
      );
      expect(again['Ardoise/ECH/ECH.md'], contains('Mes notes.'));
    });

    test('l’ancienne propriété votes disparaît à la réécriture', () {
      final first = renderVault(_seed());
      final old = {
        ...first,
        'Ardoise/ECH/ECH-48.md': first['Ardoise/ECH/ECH-48.md']!.replaceFirst(
          'ardoise: demande',
          'ardoise: demande\nvotes:\n  - "[[Tom]]"',
        ),
      };
      final again = renderVault(_seed(), existing: old);
      expect(
        parseNote(again['Ardoise/ECH/ECH-48.md']!).properties,
        isNot(contains('votes')),
      );
    });

    test('une modification faite dans Obsidian est lue', () {
      final files = renderVault(_seed());
      files['Ardoise/ECH/ECH-48.md'] = files['Ardoise/ECH/ECH-48.md']!
          .replaceFirst('statut: à faire', 'statut: En cours');
      final back = decodeVault(files, now: _now).snapshot!;
      expect(
        back.requests
            .singleWhere((r) => r.projectId == 'echeo' && r.number == 48)
            .status,
        RequestStatus.doing,
      );
    });

    test('une demande créée à la main reçoit le numéro suivant', () {
      final files = renderVault(_seed())
        ..['Ardoise/ECH/Corriger le login.md'] =
            '---\nardoise: demande\ntype: bug\n---\nÇa coince.\n';
      final contents = decodeVault(files, now: _now);
      final max = seedRequests
          .where((r) => r.projectId == 'echeo')
          .map((r) => r.number)
          .reduce((a, b) => a > b ? a : b);
      final created = contents.snapshot!.requests.singleWhere(
        (r) => r.projectId == 'echeo' && r.number == max + 1,
      );
      expect(created.title, 'Corriger le login');
      expect(created.description, 'Ça coince.');
      expect(created.status, RequestStatus.todo);
      expect(created.createdAt, _now);
      // Sans demandeur, c'est moi.
      expect(created.requesterId, seedCurrentUserId);
      expect(contents.adoptedPaths, {'Ardoise/ECH/Corriger le login.md'});
    });

    test('un nom qui finit par un nombre n’est pas un numéro', () {
      final files = renderVault(_seed())
        ..['Ardoise/ECH/import-01.md'] =
            '---\nardoise: demande\ntitre: Importée\n---\n';
      final contents = decodeVault(files, now: _now);
      expect(contents.problems, isEmpty, reason: 'pas un doublon de ECH-1');
      expect(contents.adoptedPaths, {'Ardoise/ECH/import-01.md'});
    });

    test('un nom CLE-n sans propriété numero garde son numéro', () {
      final files = renderVault(_seed())
        ..['Ardoise/ECH/ECH-900.md'] =
            '---\nardoise: demande\ntitre: Copiée à la main\n---\n';
      final contents = decodeVault(files, now: _now);
      expect(contents.adoptedPaths, isEmpty);
      expect(
        contents.snapshot!.requests.any(
          (r) => r.projectId == 'echeo' && r.number == 900,
        ),
        isTrue,
      );
    });

    test('une valeur inconnue fait ignorer la note, pas tout le vault', () {
      final files = renderVault(_seed());
      files['Ardoise/ECH/ECH-48.md'] = files['Ardoise/ECH/ECH-48.md']!
          .replaceFirst('statut: à faire', 'statut: bloqué');
      final contents = decodeVault(files, now: _now);
      expect(contents.problems.single, contains('bloqué'));
      expect(
        contents.snapshot!.requests.where(
          (r) => r.projectId == 'echeo' && r.number == 48,
        ),
        isEmpty,
      );
      expect(contents.snapshot!.requests.length, seedRequests.length - 1);
    });

    test('un numéro en double est signalé, pas fusionné', () {
      final files = renderVault(_seed());
      files['Ardoise/ECH/ECH-48 copie.md'] = files['Ardoise/ECH/ECH-48.md']!;
      final contents = decodeVault(files, now: _now);
      expect(contents.problems.single, contains('ECH-48'));
      expect(contents.snapshot!.requests.length, seedRequests.length);
    });

    test('une personne citée sans note est ajoutée', () {
      final files = renderVault(_seed());
      files['Ardoise/ECH/ECH-48.md'] = files['Ardoise/ECH/ECH-48.md']!
          .replaceFirst('intervenant: "[[Dana]]"', 'intervenant: "[[Zoé]]"');
      final back = decodeVault(files, now: _now).snapshot!;
      final zoe = back.people!.singleWhere((p) => p.name == 'Zoé');
      expect(
        back.requests
            .singleWhere((r) => r.projectId == 'echeo' && r.number == 48)
            .assigneeId,
        zoe.id,
      );
    });

    test('un dossier de projet sans sa note est reconnu', () {
      final files = renderVault(_seed())..remove('Ardoise/ATL/ATL.md');
      final back = decodeVault(files, now: _now).snapshot!;
      expect(back.projects.map((p) => p.key), containsAll(['ECH', 'ATL']));
    });

    test('les notes sans propriété ardoise sont ignorées', () {
      final files = renderVault(_seed())
        ..['Ardoise/ECH/Brouillon.md'] = 'Juste une note à moi.';
      final contents = decodeVault(files, now: _now);
      expect(contents.problems, isEmpty);
      expect(contents.snapshot!.requests.length, seedRequests.length);
    });
  });
}
