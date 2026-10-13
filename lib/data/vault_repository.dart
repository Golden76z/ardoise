import 'dart:async';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'repository.dart';
import 'seed.dart';
import 'vault_format.dart';

/// Les demandes vivent dans un vault Obsidian, une note par demande (le
/// format est dans `vault_format.dart`). Bureau uniquement : `dart:io`.
///
/// Deux règles tiennent la synchronisation :
///
/// 1. **L'app n'écrit que ce qu'elle a changé.** À chaque sauvegarde, on
///    compare le rendu du nouvel état à celui du dernier état connu, et on
///    n'écrit que les notes qui diffèrent. Une note modifiée dans Obsidian
///    entre-temps n'est donc pas écrasée par une modification sans rapport
///    faite dans l'app.
/// 2. **Le disque fait foi.** Le dossier est relu dès que sa signature
///    (chemins, dates, tailles) change, et l'état relu remplace celui de
///    l'app via `externalChanges`.
///
/// Lectures et écritures passent par une même file : une relecture ne voit
/// jamais une sauvegarde à moitié faite.
class VaultRepository implements ArdoiseRepository {
  VaultRepository(
    String vaultPath, {
    this.pollInterval = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : vaultPath = _trimSeparators(vaultPath),
       _now = now ?? DateTime.now;

  final String vaultPath;
  final Duration pollInterval;
  final DateTime Function() _now;

  @override
  String? lastLoadError;

  @override
  String? lastLoadWarning;

  /// Rendu (sans le contenu du disque) du dernier état synchronisé. C'est la
  /// référence de la règle 1.
  Map<String, String> _lastRendered = const {};

  /// Tant que la dernière lecture a échoué, on n'écrit rien : l'app tourne
  /// alors sur des données d'exemple, qui écraseraient les vraies notes.
  bool _loadFailed = false;

  String? _signature;
  Future<void> _queue = Future.value();
  StreamController<ArdoiseSnapshot>? _changes;
  Timer? _timer;

  static String _trimSeparators(String path) {
    var clean = path.trim();
    while (clean.length > 1 && (clean.endsWith('/') || clean.endsWith(r'\'))) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  String get _sep => Platform.pathSeparator;

  String _absolute(String relative) =>
      '$vaultPath$_sep${relative.replaceAll('/', _sep)}';

  String _relative(String absolute) => absolute
      .substring(vaultPath.length)
      .replaceAll(r'\', '/')
      .replaceFirst(RegExp('^/+'), '');

  Directory get _root => Directory(_absolute(vaultFolder));

  /// Toutes les notes `.md` du dossier Ardoise, fichiers cachés exclus (dont
  /// nos fichiers temporaires).
  Stream<File> _noteFiles() async* {
    final root = _root;
    if (!await root.exists()) return;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = _relative(entity.path);
      if (!relative.toLowerCase().endsWith('.md')) continue;
      if (relative.split('/').any((part) => part.startsWith('.'))) continue;
      yield entity;
    }
  }

  Future<({Map<String, String> files, List<String> problems})>
  _readAll() async {
    final files = <String, String>{};
    final problems = <String>[];
    await for (final file in _noteFiles()) {
      final relative = _relative(file.path);
      try {
        files[relative] = await file.readAsString();
      } on Object catch (error) {
        problems.add('$relative : illisible ($error).');
      }
    }
    return (files: files, problems: problems);
  }

  Future<String> _computeSignature() async {
    final parts = <String>[];
    await for (final file in _noteFiles()) {
      try {
        final stat = await file.stat();
        parts.add(
          '${_relative(file.path)}|${stat.modified.microsecondsSinceEpoch}'
          '|${stat.size}',
        );
      } on Object {
        // Fichier supprimé pendant le parcours : la prochaine passe le verra.
      }
    }
    parts.sort();
    return parts.join('\n');
  }

  /// Écrit à côté puis renomme : Obsidian, ou un `git pull`, ne lit jamais
  /// une note à moitié écrite.
  Future<void> _writeFile(String relative, String text) async {
    final target = File(_absolute(relative));
    await target.parent.create(recursive: true);
    final name = relative.split('/').last;
    final temp = File('${target.parent.path}$_sep.$name.ardoise-tmp');
    await temp.writeAsString(text, flush: true);
    await temp.rename(target.path);
  }

  Future<void> _deleteFile(String relative) async {
    final file = File(_absolute(relative));
    if (await file.exists()) await file.delete();
    // Un projet supprimé ne laisse pas de dossier vide derrière lui.
    final parent = file.parent;
    if (parent.path != _root.path &&
        await parent.exists() &&
        await parent.list().isEmpty) {
      await parent.delete();
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final run = _queue.then((_) => task());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  @override
  Future<ArdoiseSnapshot?> load() => _enqueue(_load);

  Future<ArdoiseSnapshot?> _load() async {
    lastLoadError = null;
    lastLoadWarning = null;
    try {
      if (!await Directory(vaultPath).exists()) {
        throw FileSystemException('vault introuvable', vaultPath);
      }
      final read = await _readAll();
      final contents = decodeVault(read.files, now: _now());
      var snapshot = contents.snapshot ?? vaultStarterSnapshot();
      if (snapshot.projects.isEmpty) {
        // Des personnes mais aucun projet : sans projet courant, l'app n'a
        // rien à afficher.
        snapshot = ArdoiseSnapshot(
          projects: vaultStarterSnapshot().projects,
          requests: snapshot.requests,
          people: snapshot.people,
          currentUserId: snapshot.currentUserId,
        );
      }

      // Ce qui manque sur le disque (vault neuf, note de projet ou de
      // personne absente, demande adoptée) est créé ; une demande adoptée
      // perd son ancien fichier. Rien d'existant n'est réécrit.
      final rendered = renderVault(snapshot, existing: read.files);
      for (final entry in rendered.entries) {
        if (!read.files.containsKey(entry.key)) {
          await _writeFile(entry.key, entry.value);
        }
      }
      for (final path in contents.adoptedPaths) {
        if (!rendered.containsKey(path)) await _deleteFile(path);
      }

      final problems = [...read.problems, ...contents.problems];
      if (problems.isNotEmpty) {
        lastLoadWarning = problems.length == 1
            ? 'Une note ignorée — ${problems.single}'
            : '${problems.length} notes ignorées — ${problems.first} '
                  '(et ${problems.length - 1} autre(s)).';
      }
      _lastRendered = renderVault(snapshot);
      _signature = await _computeSignature();
      _loadFailed = false;
      return snapshot;
    } on Object catch (error) {
      _loadFailed = true;
      lastLoadError = '$error';
      return null;
    }
  }

  @override
  Future<void> save(ArdoiseSnapshot snapshot) => _enqueue(() async {
    if (_loadFailed) {
      throw StateError(
        'le vault n’a pas pu être lu, rien n’est écrit pour ne pas écraser '
        'tes notes',
      );
    }
    final rendered = renderVault(snapshot);
    final disk = (await _readAll()).files;
    // Le texte écrit garde ce qui a été ajouté dans Obsidian (tags…).
    final full = renderVault(snapshot, existing: disk);
    for (final entry in rendered.entries) {
      if (_lastRendered[entry.key] == entry.value) continue;
      final text = full[entry.key]!;
      final current = disk[entry.key];
      if (current != null && sameNote(current, text)) continue;
      await _writeFile(entry.key, text);
    }
    for (final path in _lastRendered.keys) {
      if (!rendered.containsKey(path) && disk.containsKey(path)) {
        await _deleteFile(path);
      }
    }
    _lastRendered = rendered;
    _signature = await _computeSignature();
  });

  @override
  Stream<ArdoiseSnapshot> get externalChanges {
    _changes ??= StreamController<ArdoiseSnapshot>.broadcast(
      onListen: () => _timer = Timer.periodic(pollInterval, (_) => _poll()),
      onCancel: () => _timer?.cancel(),
    );
    return _changes!.stream;
  }

  bool _polling = false;

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      // Dans la file : la signature n'est jamais prise au milieu d'une
      // sauvegarde, qui la met elle-même à jour en finissant.
      final snapshot = await _enqueue(() async {
        if (await _computeSignature() == _signature) return null;
        return _load();
      });
      if (snapshot != null) _changes?.add(snapshot);
    } on Object {
      // Une passe ratée n'est pas grave : la suivante réessaie.
    } finally {
      _polling = false;
    }
  }

  /// Pour les tests : relit tout de suite au lieu d'attendre le minuteur.
  Future<void> pollNow() => _poll();
}

/// Où est le vault. Retenu dans les préférences ; `ARDOISE_VAULT` le force.
abstract final class VaultLocation {
  static const preferenceKey = 'ardoise.vaultPath';

  /// Le chemin imposé par `ARDOISE_VAULT`, s'il y en a un. Il n'est jamais
  /// retenu : lancer la démo ne doit pas faire oublier son vrai vault.
  static String? get forced {
    final value = Platform.environment['ARDOISE_VAULT'];
    return value == null || value.trim().isEmpty ? null : normalize(value);
  }

  static Future<String?> saved() async {
    if (forced case final path?) return path;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(preferenceKey);
    } on Object {
      return null;
    }
  }

  static Future<void> remember(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, normalize(path));
  }

  static Future<void> forget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(preferenceKey);
  }

  /// Retire les guillemets d'un chemin collé, et déplie `~`.
  static String normalize(String path) {
    var clean = path.trim();
    if (clean.length >= 2 &&
        (clean.startsWith('"') && clean.endsWith('"') ||
            clean.startsWith("'") && clean.endsWith("'"))) {
      clean = clean.substring(1, clean.length - 1).trim();
    }
    if (clean == '~' || clean.startsWith('~/') || clean.startsWith(r'~\')) {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) clean = '$home${clean.substring(1)}';
    }
    return clean;
  }

  /// `null` si le dossier est un vault utilisable, sinon le motif à afficher.
  static Future<String?> check(String path) async {
    final clean = normalize(path);
    if (clean.isEmpty) return 'Indique le dossier de ton vault Obsidian.';
    if (!await Directory(clean).exists()) return 'Ce dossier n’existe pas.';
    final marker = Directory('$clean${Platform.pathSeparator}.obsidian');
    if (!await marker.exists()) {
      return 'Ce dossier n’est pas un vault Obsidian (pas de dossier .obsidian).';
    }
    return null;
  }
}
