import 'dart:convert';

import '../models/models.dart';
import '../theme/tokens.dart';

/// Le format d'Ardoise dans un vault Obsidian. Aucune entrée-sortie ici : on
/// passe de « chemin → texte » à un `ArdoiseSnapshot` et retour, ce qui se
/// teste sans disque. `VaultRepository` ne fait que lire et écrire les
/// fichiers.
///
/// ```text
/// Ardoise/Ardoise.md              index : qui je suis
/// Ardoise/Personnes/Dana.md     une note par personne
/// Ardoise/PRJ/PRJ.md              la note du projet (corps libre)
/// Ardoise/PRJ/PRJ-12.md           une note par demande ; corps = description
/// ```
///
/// Seules les notes qui portent la propriété `ardoise` sont lues, et Ardoise
/// ne supprime que ce qu'elle a elle-même produit. Les autres notes du vault
/// ne sont jamais touchées.
const vaultFolder = 'Ardoise';

const _indexPath = '$vaultFolder/Ardoise.md';
const _peopleFolder = 'Personnes';

/// Une note : ses propriétés (le frontmatter YAML) et son corps.
///
/// Les valeurs sont des `String`, `int`, `bool`, `null`, `DateTime` (à
/// l'écriture) ou `List<String>`. C'est le sous-ensemble de YAML qu'Obsidian
/// produit dans son panneau « Propriétés » — pas besoin d'une dépendance.
class Note {
  const Note(this.properties, this.body);

  final Map<String, Object?> properties;
  final String body;
}

// — Lecture et écriture d'une note —

final _keyLine = RegExp(r'^([^\s#:\-][^:]*):(?:\s+(.*))?$');
final _listItem = RegExp(r'^\s*-(?:\s+(.*))?$');
final _intPattern = RegExp(r'^-?\d+$');

Note parseNote(String text) {
  final lines = text.replaceAll('\r\n', '\n').split('\n');
  if (lines.isEmpty || lines.first.trimRight() != '---') {
    return Note(const {}, text);
  }
  final close = lines.indexWhere((l) => l.trimRight() == '---', 1);
  if (close < 0) return Note(const {}, text);

  final properties = <String, Object?>{};
  var i = 1;
  while (i < close) {
    final match = _keyLine.firstMatch(lines[i]);
    i++;
    if (match == null) continue;
    final key = match.group(1)!.trim();
    final rest = (match.group(2) ?? '').trim();
    if (rest.isEmpty) {
      // Liste en blocs (ce qu'écrit Obsidian), ou valeur vide.
      final items = <String>[];
      while (i < close) {
        final item = _listItem.firstMatch(lines[i]);
        if (item == null) break;
        final value = _scalar((item.group(1) ?? '').trim());
        if (value != null) items.add('$value');
        i++;
      }
      properties[key] = items.isEmpty ? null : items;
    } else if (rest.startsWith('[') &&
        rest.endsWith(']') &&
        !rest.startsWith('[[')) {
      properties[key] = _flowList(rest.substring(1, rest.length - 1));
    } else {
      properties[key] = _scalar(rest);
    }
  }
  return Note(properties, lines.sublist(close + 1).join('\n'));
}

Object? _scalar(String raw) {
  if (raw.isEmpty) return null;
  if (raw.length >= 2 && raw.startsWith('"') && raw.endsWith('"')) {
    try {
      return jsonDecode(raw) as String;
    } on Object {
      return raw.substring(1, raw.length - 1);
    }
  }
  if (raw.length >= 2 && raw.startsWith("'") && raw.endsWith("'")) {
    return raw.substring(1, raw.length - 1).replaceAll("''", "'");
  }
  var plain = raw;
  final comment = plain.indexOf(' #');
  if (comment >= 0) plain = plain.substring(0, comment).trimRight();
  final lower = plain.toLowerCase();
  if (lower == '~' || lower == 'null') return null;
  if (lower == 'true') return true;
  if (lower == 'false') return false;
  if (_intPattern.hasMatch(plain)) return int.parse(plain);
  return plain;
}

List<String> _flowList(String inner) {
  final items = <String>[];
  final current = StringBuffer();
  String? quote;
  for (final char in inner.split('')) {
    if (quote != null) {
      current.write(char);
      if (char == quote) quote = null;
    } else if (char == '"' || char == "'") {
      quote = char;
      current.write(char);
    } else if (char == ',') {
      items.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  items.add(current.toString());
  return [
    for (final item in items)
      if (_scalar(item.trim()) case final Object value) '$value',
  ];
}

String writeNote(Note note) {
  final out = StringBuffer('---\n');
  note.properties.forEach((key, value) {
    if (value == null) {
      out.writeln('$key:');
    } else if (value is List) {
      if (value.isEmpty) {
        out.writeln('$key: []');
      } else {
        out.writeln('$key:');
        for (final item in value) {
          out.writeln('  - ${_yaml(item as Object)}');
        }
      }
    } else {
      out.writeln('$key: ${_yaml(value)}');
    }
  });
  out.write('---\n');
  final body = note.body;
  if (body.trim().isNotEmpty) {
    out.write(body.endsWith('\n') ? body : '$body\n');
  }
  return out.toString();
}

final _plainText = RegExp(r"^[\p{L}\p{N}][\p{L}\p{N} .,_/()'’!?+-]*$", unicode: true);
const _yamlWords = {'true', 'false', 'yes', 'no', 'on', 'off', 'null', 'y', 'n'};

String _yaml(Object value) {
  if (value is int || value is bool) return '$value';
  if (value is DateTime) return _isoSeconds(value);
  final text = '$value';
  final plain =
      _plainText.hasMatch(text) &&
      text.trim() == text &&
      num.tryParse(text) == null &&
      !_yamlWords.contains(text.toLowerCase());
  // Les échappements JSON sont aussi ceux d'une chaîne YAML entre guillemets.
  return plain ? text : jsonEncode(text);
}

/// Format date-heure des propriétés Obsidian : sans millisecondes.
String _isoSeconds(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
      'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

/// « 2026-10-09 » : une date sans heure, que le panneau Propriétés
/// d'Obsidian affiche comme une date.
String _isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Même contenu, à la mise en forme près. Sert à ne pas réécrire une note
/// qu'Obsidian a simplement reformatée : chaque écriture inutile, c'est du
/// bruit dans l'historique Git du vault.
bool sameNote(String a, String b) {
  final left = parseNote(a);
  final right = parseNote(b);
  if (left.body.trim() != right.body.trim()) return false;
  if (left.properties.length != right.properties.length) return false;
  for (final entry in left.properties.entries) {
    if (!right.properties.containsKey(entry.key)) return false;
    if (jsonEncode(entry.value) != jsonEncode(right.properties[entry.key])) {
      return false;
    }
  }
  return true;
}

// — Petits utilitaires —

/// Nom de fichier valable sur Windows comme sur Linux, et utilisable dans un
/// lien Obsidian (ni `#`, ni `^`, ni `|`, ni crochets).
String fileSafe(String name) {
  var clean = name.replaceAll(RegExp(r'[\\/:*?"<>|#^\[\]]'), '-').trim();
  clean = clean.replaceAll(RegExp(r'[. ]+$'), '');
  return clean.isEmpty ? 'sans-nom' : clean;
}

/// « [[Dana]] » → « Dana » ; tolère « [[Personnes/Dana|D.]] » et un nom
/// nu tapé à la main.
String? linkTarget(Object? value) {
  if (value == null) return null;
  var text = '$value'.trim();
  if (text.startsWith('[[') && text.endsWith(']]')) {
    text = text.substring(2, text.length - 2);
  }
  final bar = text.indexOf('|');
  if (bar >= 0) text = text.substring(0, bar);
  final slash = text.lastIndexOf('/');
  if (slash >= 0) text = text.substring(slash + 1);
  if (text.toLowerCase().endsWith('.md')) {
    text = text.substring(0, text.length - 3);
  }
  text = text.trim();
  return text.isEmpty ? null : text;
}

String _colorHex(Color color) {
  final argb = color.toARGB32();
  return (argb >>> 24) == 0xFF
      ? '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}'
      : '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Color? _parseColor(Object? value) {
  if (value == null) return null;
  var hex = '$value'.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) return null;
  if (hex.length == 6) return Color(0xFF000000 | parsed);
  if (hex.length == 8) return Color(parsed);
  return null;
}

/// Comparaison tolérante : « À faire », « a faire », « todo » se valent.
String _fold(String text) {
  const from = 'àâäéèêëîïôöûüùç';
  const to = 'aaaeeeeiioouuuc';
  final lower = text.trim().toLowerCase();
  final out = StringBuffer();
  for (final char in lower.split('')) {
    final i = from.indexOf(char);
    out.write(i >= 0 ? to[i] : char);
  }
  return out.toString();
}

RequestType? _parseType(Object? value) {
  final key = _fold('$value');
  for (final type in RequestType.values) {
    if (key == _fold(type.label) || key == type.name) return type;
  }
  return null;
}

RequestPriority? _parsePriority(Object? value) {
  final key = _fold('$value');
  for (final priority in RequestPriority.values) {
    if (key == _fold(priority.label) || key == priority.name) return priority;
  }
  return null;
}

RequestStatus? _parseStatus(Object? value) {
  final key = _fold('$value');
  for (final status in RequestStatus.values) {
    if (key == _fold(status.label) || key == status.name) return status;
  }
  return null;
}

String _stem(String path) {
  final name = path.split('/').last;
  return name.toLowerCase().endsWith('.md')
      ? name.substring(0, name.length - 3)
      : name;
}

// — Vault → snapshot —

/// Ce qu'une lecture du vault rapporte.
class VaultContents {
  const VaultContents({
    required this.snapshot,
    required this.adoptedPaths,
    required this.problems,
  });

  /// `null` quand le dossier ne contient aucune note d'Ardoise.
  final ArdoiseSnapshot? snapshot;

  /// Notes de demande créées à la main, sans numéro : elles en ont reçu un,
  /// et le dépôt doit les réécrire sous `CLE-n.md` puis supprimer l'original.
  /// Sinon le numéro changerait à chaque lecture, et une modification dans
  /// l'app créerait une seconde copie.
  final Set<String> adoptedPaths;

  /// Une ligne par note ignorée, pour le bandeau.
  final List<String> problems;
}

/// `files` : chemins relatifs au vault, séparés par `/`, notes `.md` du
/// dossier `Ardoise` uniquement. `now` date une demande créée à la main
/// sans date.
VaultContents decodeVault(Map<String, String> files, {required DateTime now}) {
  final problems = <String>[];
  final notes = <String, Note>{
    for (final entry in files.entries) entry.key: parseNote(entry.value),
  };
  Iterable<MapEntry<String, Note>> ofKind(String kind) => notes.entries.where(
    (e) => '${e.value.properties['ardoise']}'.trim().toLowerCase() == kind,
  );
  // Ordre stable, quel que soit l'ordre du disque : la propriété `ordre`
  // d'abord (le premier projet est celui sur lequel l'app s'ouvre), puis le
  // chemin.
  int rank(Note note) {
    final value = note.properties['ordre'];
    return value is int ? value : 1 << 30;
  }

  List<MapEntry<String, Note>> sorted(String kind) => ofKind(kind).toList()
    ..sort((a, b) {
      final byRank = rank(a.value).compareTo(rank(b.value));
      return byRank != 0 ? byRank : a.key.compareTo(b.key);
    });

  // Personnes.
  final people = <Person>[];
  final personByKey = <String, String>{};
  void index(Person person, String stem) {
    personByKey[person.id.toLowerCase()] = person.id;
    personByKey[person.name.toLowerCase()] = person.id;
    personByKey[stem.toLowerCase()] = person.id;
  }

  for (final entry in sorted('personne')) {
    final props = entry.value.properties;
    final stem = _stem(entry.key);
    final id = '${props['id'] ?? 'p-${stem.toLowerCase()}'}';
    if (people.any((p) => p.id == id)) {
      problems.add('${entry.key} : identifiant de personne « $id » en doublon.');
      continue;
    }
    final person = Person(
      id: id,
      name: props['nom'] == null ? stem : '${props['nom']}',
      color:
          _parseColor(props['couleur']) ??
          T.personPalette[people.length % T.personPalette.length],
    );
    people.add(person);
    index(person, stem);
  }

  String? resolvePerson(Object? value) {
    final target = linkTarget(value);
    if (target == null) return null;
    final known = personByKey[target.toLowerCase()];
    if (known != null) return known;
    // Un lien vers quelqu'un qui n'a pas encore de note : on l'ajoute. La
    // prochaine écriture lui créera sa note.
    final person = Person(
      id: 'p-${fileSafe(target).toLowerCase()}',
      name: target,
      color: T.personPalette[people.length % T.personPalette.length],
    );
    people.add(person);
    index(person, target);
    return person.id;
  }

  // Index.
  String? currentUserId;
  final indexNote = notes[_indexPath];
  if (indexNote != null &&
      '${indexNote.properties['ardoise']}'.toLowerCase() == 'index') {
    currentUserId = resolvePerson(indexNote.properties['utilisateur']);
  }

  // Projets : un dossier par projet, nommé d'après sa clé.
  final projects = <Project>[];
  final projectByFolder = <String, Project>{};
  for (final entry in sorted('projet')) {
    final parts = entry.key.split('/');
    if (parts.length != 3) {
      problems.add('${entry.key} : une note de projet doit être dans son dossier.');
      continue;
    }
    final folder = parts[1];
    final props = entry.value.properties;
    final key = '${props['cle'] ?? folder}'.trim().toUpperCase();
    final id = '${props['id'] ?? key.toLowerCase()}';
    if (projectByFolder.containsKey(folder) ||
        projects.any((p) => p.id == id || p.key == key)) {
      problems.add('${entry.key} : projet « $key » en double.');
      continue;
    }
    final project = Project(
      id: id,
      key: key,
      name: '${props['nom'] ?? key}',
      milestoneName: '${props['jalon'] ?? ''}',
      color:
          _parseColor(props['couleur']) ??
          T.projectPalette[projects.length % T.projectPalette.length],
    );
    projects.add(project);
    projectByFolder[folder] = project;
  }

  // Demandes.
  final requests = <Request>[];
  final unnumbered = <({String path, Request request})>[];
  for (final entry in sorted('demande')) {
    final parts = entry.key.split('/');
    if (parts.length != 3 || parts[1] == _peopleFolder) {
      problems.add('${entry.key} : une demande doit être dans le dossier de son projet.');
      continue;
    }
    final folder = parts[1];
    final project = projectByFolder.putIfAbsent(folder, () {
      // Dossier sans note de projet (supprimée, ou créé dans Obsidian) : on
      // le reconnaît quand même. La prochaine écriture lui rendra sa note.
      final created = Project(
        id: folder.toLowerCase(),
        key: folder.toUpperCase(),
        name: folder,
        milestoneName: '',
        color: T.projectPalette[projects.length % T.projectPalette.length],
      );
      projects.add(created);
      return created;
    });
    final props = entry.value.properties;
    final stem = _stem(entry.key);

    final type = props['type'] == null
        ? RequestType.feature
        : _parseType(props['type']);
    if (type == null) {
      problems.add('${entry.key} : type « ${props['type']} » inconnu (bug, fonctionnalité ou idée).');
      continue;
    }
    final status = props['statut'] == null
        ? RequestStatus.todo
        : _parseStatus(props['statut']);
    if (status == null) {
      problems.add('${entry.key} : statut « ${props['statut']} » inconnu (à faire, en cours, en revue ou fait).');
      continue;
    }
    final priority = props['priorite'] == null
        ? RequestPriority.medium
        : _parsePriority(props['priorite']);
    if (priority == null) {
      problems.add('${entry.key} : priorité « ${props['priorite']} » inconnue (basse, moyenne, haute ou urgente).');
      continue;
    }
    DateTime? dueDate;
    if (props['echeance'] != null) {
      final parsed = DateTime.tryParse('${props['echeance']}');
      if (parsed == null) {
        problems.add('${entry.key} : échéance « ${props['echeance']} » illisible.');
        continue;
      }
      dueDate = DateTime(parsed.year, parsed.month, parsed.day);
    }
    DateTime createdAt = now;
    if (props['cree'] != null) {
      final parsed = DateTime.tryParse('${props['cree']}');
      if (parsed == null) {
        problems.add('${entry.key} : date « ${props['cree']} » illisible.');
        continue;
      }
      createdAt = parsed;
    }

    final title = '${props['titre'] ?? ''}'.trim();
    final request = Request(
      number: 0,
      projectId: project.id,
      title: title.isEmpty ? stem : title,
      description: entry.value.body.trim(),
      type: type,
      status: status,
      // Résolu plus bas si absent : l'index n'est peut-être pas encore lu.
      requesterId: resolvePerson(props['demandeur']) ?? '',
      assigneeId: resolvePerson(props['intervenant']),
      createdAt: createdAt,
      priority: priority,
      dueDate: dueDate,
    );

    final number = props['numero'] is int
        ? props['numero']! as int
        : int.tryParse(RegExp(r'-(\d+)$').firstMatch(stem)?.group(1) ?? '');
    if (number == null) {
      // Note créée à la main dans Obsidian : elle reçoit le prochain numéro,
      // et la prochaine écriture la renommera en `CLE-n.md`.
      unnumbered.add((path: entry.key, request: request));
      continue;
    }
    if (requests.any((r) => r.projectId == project.id && r.number == number)) {
      problems.add('${entry.key} : ${project.key}-$number existe déjà.');
      continue;
    }
    requests.add(_withNumber(request, number));
  }
  for (final item in unnumbered) {
    final next =
        requests
            .where((r) => r.projectId == item.request.projectId)
            .fold(0, (max, r) => r.number > max ? r.number : max) +
        1;
    requests.add(_withNumber(item.request, next));
  }

  if (projects.isEmpty && requests.isEmpty && people.isEmpty) {
    return VaultContents(
      snapshot: null,
      adoptedPaths: const {},
      problems: problems,
    );
  }

  final me = currentUserId ?? (people.isEmpty ? null : people.first.id);
  return VaultContents(
    snapshot: ArdoiseSnapshot(
      projects: projects,
      requests: [
        for (final r in requests)
          r.requesterId.isEmpty && me != null ? _withRequester(r, me) : r,
      ],
      people: people,
      currentUserId: me,
    ),
    adoptedPaths: {for (final item in unnumbered) item.path},
    problems: problems,
  );
}

Request _withNumber(Request r, int number) => Request(
  number: number,
  projectId: r.projectId,
  title: r.title,
  description: r.description,
  type: r.type,
  status: r.status,
  requesterId: r.requesterId,
  assigneeId: r.assigneeId,
  createdAt: r.createdAt,
  priority: r.priority,
  dueDate: r.dueDate,
);

Request _withRequester(Request r, String requesterId) => Request(
  number: r.number,
  projectId: r.projectId,
  title: r.title,
  description: r.description,
  type: r.type,
  status: r.status,
  requesterId: requesterId,
  assigneeId: r.assigneeId,
  createdAt: r.createdAt,
  priority: r.priority,
  dueDate: r.dueDate,
);

// — Snapshot → vault —

const _indexBody = '''
Ce dossier est tenu par l’app **Ardoise**. Chaque sous-dossier est un projet,
chaque note `CLE-n` une demande : modifie-les ici ou dans l’app, les deux
restent d’accord.

Pour créer une demande depuis Obsidian, une note dans le dossier du projet
suffit, avec au minimum la propriété `ardoise: demande` (et `titre`, `type`,
`statut` si tu veux) : Ardoise lui donne un numéro et la renomme.
''';

/// Chemin → texte de chaque note que l'état décrit. `existing` (le contenu
/// actuel du disque) sert à garder ce qu'on ajoute dans Obsidian : les
/// propriétés inconnues d'Ardoise (tags, alias…) et le corps des notes de
/// projet et de personne, qui sont des espaces libres.
Map<String, String> renderVault(
  ArdoiseSnapshot snapshot, {
  Map<String, String> existing = const {},
}) {
  final out = <String, String>{};
  void emit(String path, Map<String, Object?> props, String body, {bool keepBody = false}) {
    final previousText = existing[path];
    final previous = previousText == null ? null : parseNote(previousText);
    final merged = {...props};
    previous?.properties.forEach((key, value) {
      // `votes` : propriété des anciennes notes, retirée avec les votes.
      if (key == 'votes') return;
      merged.putIfAbsent(key, () => value);
    });
    final finalBody = keepBody && previous != null && previous.body.trim().isNotEmpty
        ? previous.body
        : body;
    out[path] = writeNote(Note(merged, finalBody));
  }

  // Personnes : le nom du fichier sert de lien.
  final people = snapshot.people ?? const <Person>[];
  final stems = <String, String>{};
  final usedStems = <String>{};
  for (final person in people) {
    var stem = fileSafe(person.name);
    if (!usedStems.add(stem.toLowerCase())) {
      stem = '$stem (${fileSafe(person.id)})';
      usedStems.add(stem.toLowerCase());
    }
    stems[person.id] = stem;
  }
  String? link(String? personId) {
    if (personId == null) return null;
    final stem = stems[personId];
    if (stem == null) return personId;
    final name = people.firstWhere((p) => p.id == personId).name;
    return stem == name ? '[[$stem]]' : '[[$stem|$name]]';
  }

  for (final (i, person) in people.indexed) {
    final stem = stems[person.id]!;
    emit(
      '$vaultFolder/$_peopleFolder/$stem.md',
      {
        'ardoise': 'personne',
        'id': person.id,
        'ordre': i,
        if (stem != person.name) 'nom': person.name,
        'couleur': _colorHex(person.color),
      },
      '',
      keepBody: true,
    );
  }

  emit(
    _indexPath,
    {'ardoise': 'index', 'utilisateur': link(snapshot.currentUserId)},
    _indexBody,
    keepBody: true,
  );

  for (final (i, project) in snapshot.projects.indexed) {
    final folder = fileSafe(project.key);
    emit(
      '$vaultFolder/$folder/$folder.md',
      {
        'ardoise': 'projet',
        'id': project.id,
        'ordre': i,
        'cle': project.key,
        'nom': project.name,
        'jalon': project.milestoneName,
        'couleur': _colorHex(project.color),
      },
      '',
      keepBody: true,
    );
    final requests =
        snapshot.requests.where((r) => r.projectId == project.id).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    for (final request in requests) {
      emit(
        '$vaultFolder/$folder/$folder-${request.number}.md',
        {
          'ardoise': 'demande',
          'numero': request.number,
          'titre': request.title,
          'type': request.type.label.toLowerCase(),
          'statut': request.status.label.toLowerCase(),
          'demandeur': link(request.requesterId),
          'intervenant': link(request.assigneeId),
          'priorite': request.priority.label.toLowerCase(),
          'echeance': request.dueDate == null
              ? null
              : _isoDay(request.dueDate!),
          'cree': request.createdAt,
        },
        request.description.trim(),
      );
    }
  }
  return out;
}
