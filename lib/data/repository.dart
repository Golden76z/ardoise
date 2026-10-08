import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'seed.dart';

/// Frontière de persistance. Le jour où une API arrive (Rust / Axum), on écrit
/// une autre implémentation ici et rien d'autre ne change.
abstract class ArdoiseRepository {
  /// `null` quand il n'y a rien à charger. Ne lève jamais : une app figée sur
  /// son indicateur de chargement serait pire que des données d'exemple.
  ///
  /// Quand l'échec n'est pas « rien d'enregistré » mais une vraie panne,
  /// `lastLoadError` le dit. Les confondre a coûté cher : un canal de
  /// plateforme indisponible rendait `null`, l'app affichait les données
  /// d'exemple sans un mot, et la première écriture les gravait.
  Future<ArdoiseSnapshot?> load();

  /// Renseigné quand le dernier `load` a échoué, `null` quand il n'y avait
  /// simplement rien d'enregistré. `ArdoiseStore.init` le remonte à l'écran.
  String? get lastLoadError;

  Future<void> save(ArdoiseSnapshot snapshot);
}

/// Un document JSON dans les préférences. Suffisant pour la V2 (mono-
/// utilisateur, quelques centaines de demandes) et identique sur web et mobile,
/// contrairement à SQLite qui réclame un worker wasm sur le web.
/// ponytail: à remplacer par une base dès que les demandes dépassent le
/// millier ou qu'une seconde personne écrit dans le même jeu de données.
class PrefsRepository implements ArdoiseRepository {
  @override
  String? lastLoadError;

  // Le projet s'est appelé Chantier jusqu'au 08/10/2026. La clé garde ce
  // nom : elle porte les données déjà enregistrées, et la renommer
  // imposerait une migration de plus pour quelque chose d'invisible.
  static const storageKey = 'chantier.snapshot.v2';

  /// Clé de la V1 : une liste nue de demandes, toutes d'Échéo.
  static const legacyKey = 'chantier.requests.v1';

  @override
  Future<ArdoiseSnapshot?> load() async {
    // `getInstance()` doit rester DANS le `try` : il échoue quand le navigateur
    // bloque les données de site, et le contrat de `load` est de ne jamais
    // lever — sinon l'app reste figée sur son indicateur de chargement.
    lastLoadError = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, Object?>) {
            return ArdoiseSnapshot.fromJson(decoded);
          }
        } on Object {
          // On ne retombe pas tout de suite sur les données d'exemple : la
          // sauvegarde V1 est peut-être encore là, et elle contient du vrai
          // travail. C'est à ça que sert de ne jamais l'effacer.
        }
      }
      return _loadLegacy(prefs);
    } on Object catch (error) {
      // Mieux vaut les données d'exemple qu'un écran blanc — mais on le dit.
      lastLoadError = '$error';
      return null;
    }
  }

  /// Reprise V1 → V2. On ne supprime pas l'ancienne clé : elle ne coûte rien
  /// et sert de filet si on revient en arrière.
  ArdoiseSnapshot? _loadLegacy(SharedPreferences prefs) {
    final raw = prefs.getString(legacyKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final requests = decoded
        .cast<Map<String, Object?>>()
        .map(Request.fromJson) // `projectId` absent → 'echeo'
        .toList();
    // Le projet d'accueil doit exister, sinon les demandes sont orphelines.
    return ArdoiseSnapshot(
      projects: [seedProjects.firstWhere((p) => p.id == 'echeo')],
      requests: requests,
    );
  }

  @override
  Future<void> save(ArdoiseSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(snapshot.toJson()));
  }
}

/// Double pour les tests : garde la dernière écriture en mémoire.
class MemoryRepository implements ArdoiseRepository {
  MemoryRepository([ArdoiseSnapshot? initial]) : stored = initial;

  @override
  String? lastLoadError;

  ArdoiseSnapshot? stored;

  /// Si non nul, `save` lève — pour tester le bandeau d'erreur.
  Object? failWith;

  /// Si non nul, `load` lève — pour tester qu'un dépôt en panne ne laisse pas
  /// l'app figée sur son indicateur de chargement.
  Object? loadFailsWith;

  @override
  Future<ArdoiseSnapshot?> load() async {
    lastLoadError = null;
    if (loadFailsWith != null) {
      lastLoadError = '$loadFailsWith';
      return null;
    }
    return stored;
  }

  @override
  Future<void> save(ArdoiseSnapshot snapshot) async {
    if (failWith != null) throw failWith!;
    stored = snapshot;
  }
}
