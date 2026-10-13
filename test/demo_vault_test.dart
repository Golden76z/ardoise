import 'dart:io';

import 'package:ardoise/data/vault_format.dart';
import 'package:ardoise/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le vault de démonstration du dépôt (`exemple/vault-demo`) doit rester
/// lisible en entier : c'est la première chose qu'un visiteur ouvre.
void main() {
  test('le vault de démo se lit sans note ignorée', () {
    final root = Directory('exemple/vault-demo');
    final files = <String, String>{
      for (final file in root.listSync(recursive: true).whereType<File>())
        if (file.path.endsWith('.md') && file.path.contains('Ardoise'))
          file.path
              .substring(root.path.length + 1)
              .replaceAll(r'\', '/'): file.readAsStringSync(),
    };
    final now = DateTime(2026, 12, 1);
    final contents = decodeVault(files, now: now);

    expect(contents.problems, isEmpty);
    expect(contents.adoptedPaths, isEmpty);
    final snapshot = contents.snapshot!;
    expect(snapshot.projects.map((p) => p.key), ['ATL', 'WEB']);
    expect(snapshot.people, hasLength(4));
    expect(snapshot.requests, hasLength(10));
    expect(snapshot.currentUserId, 'camille');
    // Sans date de création, une demande est datée du jour : la démo
    // s'affiche dans le mois courant, quel qu'il soit.
    expect(snapshot.requests.every((r) => r.createdAt == now), isTrue);
    expect(
      snapshot.requests.map((r) => r.priority).toSet(),
      RequestPriority.values.toSet(),
    );
  });
}
