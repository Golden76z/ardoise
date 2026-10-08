import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'seed.dart';

/// Frontière de persistance. Le jour où une API arrive (Rust / Axum), on écrit
/// une autre implémentation ici et rien d'autre ne change.
abstract class ChantierRepository {
  /// `null` quand il n'y a rien d'exploitable : premier lancement, ou données
  /// illisibles. L'appelant repart alors des données d'exemple.
  ///
  /// ponytail: `null` confond « rien d'enregistré » et « enregistré mais
  /// illisible ». Dans le second cas l'utilisateur voit les données d'exemple
  /// sans un mot, et sa première écriture les grave. Aucun chemin connu ne
  /// produit un document V2 malformé aujourd'hui ; à distinguer (un champ
  /// d'erreur sur le dépôt, lu par `ChantierStore.init`) dès le prochain
  /// changement de schéma.
  Future<ChantierSnapshot?> load();

  Future<void> save(ChantierSnapshot snapshot);
}

/// Un document JSON dans les préférences. Suffisant pour la V2 (mono-
/// utilisateur, quelques centaines de demandes) et identique sur web et mobile,
/// contrairement à SQLite qui réclame un worker wasm sur le web.
/// ponytail: à remplacer par une base dès que les demandes dépassent le
/// millier ou qu'une seconde personne écrit dans le même jeu de données.
class PrefsRepository implements ChantierRepository {
  static const storageKey = 'chantier.snapshot.v2';

  /// Clé de la V1 : une liste nue de demandes, toutes d'Échéo.
  static const legacyKey = 'chantier.requests.v1';

  @override
  Future<ChantierSnapshot?> load() async {
    // `getInstance()` doit rester DANS le `try` : il échoue quand le navigateur
    // bloque les données de site, et le contrat de `load` est de ne jamais
    // lever — sinon l'app reste figée sur son indicateur de chargement.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, Object?>) {
            return ChantierSnapshot.fromJson(decoded);
          }
        } on Object {
          // On ne retombe pas tout de suite sur les données d'exemple : la
          // sauvegarde V1 est peut-être encore là, et elle contient du vrai
          // travail. C'est à ça que sert de ne jamais l'effacer.
        }
      }
      return _loadLegacy(prefs);
    } on Object {
      // Ancien format ou document corrompu : mieux vaut les données d'exemple
      // qu'un écran blanc.
      return null;
    }
  }

  /// Reprise V1 → V2. On ne supprime pas l'ancienne clé : elle ne coûte rien
  /// et sert de filet si on revient en arrière.
  ChantierSnapshot? _loadLegacy(SharedPreferences prefs) {
    final raw = prefs.getString(legacyKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final requests = decoded
        .cast<Map<String, Object?>>()
        .map(Request.fromJson) // `projectId` absent → 'echeo'
        .toList();
    // Le projet d'accueil doit exister, sinon les demandes sont orphelines.
    return ChantierSnapshot(
      projects: [seedProjects.firstWhere((p) => p.id == 'echeo')],
      requests: requests,
    );
  }

  @override
  Future<void> save(ChantierSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(snapshot.toJson()));
  }
}

/// Double pour les tests : garde la dernière écriture en mémoire.
class MemoryRepository implements ChantierRepository {
  MemoryRepository([ChantierSnapshot? initial]) : stored = initial;

  ChantierSnapshot? stored;

  /// Si non nul, `save` lève — pour tester le bandeau d'erreur.
  Object? failWith;

  /// Si non nul, `load` lève — pour tester qu'un dépôt en panne ne laisse pas
  /// l'app figée sur son indicateur de chargement.
  Object? loadFailsWith;

  @override
  Future<ChantierSnapshot?> load() async {
    if (loadFailsWith != null) throw loadFailsWith!;
    return stored;
  }

  @override
  Future<void> save(ChantierSnapshot snapshot) async {
    if (failWith != null) throw failWith!;
    stored = snapshot;
  }
}
