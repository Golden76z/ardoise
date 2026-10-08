import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Frontière de persistance. Le jour où une API arrive (Go ou Rust), on écrit
/// une autre implémentation ici et rien d'autre ne change.
abstract class ChantierRepository {
  /// `null` quand il n'y a rien d'exploitable : premier lancement, ou données
  /// illisibles. L'appelant repart alors des données d'exemple.
  Future<List<Request>?> load();

  Future<void> save(List<Request> requests);
}

/// Un document JSON dans les préférences. Suffisant pour la V1 (mono-
/// utilisateur, quelques centaines de demandes) et identique sur web et mobile,
/// contrairement à SQLite qui réclame un worker wasm sur le web.
/// ponytail: à remplacer par une base dès que les demandes dépassent le
/// millier ou qu'une seconde personne écrit dans le même jeu de données.
class PrefsRepository implements ChantierRepository {
  static const storageKey = 'chantier.requests.v1';

  @override
  Future<List<Request>?> load() async {
    // `getInstance()` doit être DANS le `try` : il échoue quand le navigateur
    // bloque les données de site, et le contrat de `load` est de ne jamais
    // lever — sinon l'app reste figée sur son indicateur de chargement.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .cast<Map<String, Object?>>()
          .map(Request.fromJson)
          .toList(growable: false);
    } on Object {
      // Ancien format ou document corrompu : mieux vaut les données d'exemple
      // qu'un écran blanc.
      return null;
    }
  }

  @override
  Future<void> save(List<Request> requests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(requests.map((r) => r.toJson()).toList()),
    );
  }
}

/// Double pour les tests : garde la dernière écriture en mémoire.
class MemoryRepository implements ChantierRepository {
  MemoryRepository([List<Request>? initial]) : stored = initial;

  List<Request>? stored;

  /// Si non nul, `save` lève — pour tester le bandeau d'erreur.
  Object? failWith;

  /// Si non nul, `load` lève — pour tester qu'un dépôt en panne ne laisse pas
  /// l'app figée sur son indicateur de chargement.
  Object? loadFailsWith;

  @override
  Future<List<Request>?> load() async {
    if (loadFailsWith != null) throw loadFailsWith!;
    return stored;
  }

  @override
  Future<void> save(List<Request> requests) async {
    if (failWith != null) throw failWith!;
    stored = List.of(requests);
  }
}
