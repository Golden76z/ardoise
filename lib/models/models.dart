import 'dart:ui' show Color;

/// `Color` est le seul emprunt au moteur de rendu : le réexporter évite à
/// `seed.dart` et aux tests de l'importer séparément.
export 'dart:ui' show Color;

enum RequestType {
  bug('Bug', 'Bugs'),
  feature('Fonctionnalité', 'Fonct.'),
  idea('Idée', 'Idées');

  const RequestType(this.label, this.shortLabel);

  /// Libellé long, pour le tiroir et la fenêtre de création.
  final String label;

  /// Libellé court, pour les puces de filtre.
  final String shortLabel;
}

enum RequestStatus {
  todo('À faire'),
  doing('En cours'),
  review('En revue'),
  done('Fait');

  const RequestStatus(this.label);
  final String label;
}

/// Ordre croissant d'importance : le tri « Par priorité » lit `index` à
/// l'envers.
enum RequestPriority {
  low('Basse'),
  medium('Moyenne'),
  high('Haute'),
  urgent('Urgente');

  const RequestPriority(this.label);
  final String label;
}

enum BoardGrouping {
  status('Statut'),
  assignee('Intervenant'),
  requester('Demandeur');

  const BoardGrouping(this.label);
  final String label;
}

enum ViewMode {
  board('Tableau'),
  list('Liste');

  const ViewMode(this.label);
  final String label;
}

enum ListSort {
  recent('Plus récentes'),
  status('Par statut'),
  priority('Par priorité'),
  due('Par échéance');

  const ListSort(this.label);
  final String label;
}

class Person {
  const Person({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;

  String get initial => name.substring(0, 1).toUpperCase();

  Person copyWith({String? name, Color? color}) =>
      Person(id: id, name: name ?? this.name, color: color ?? this.color);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    // `Color.toARGB32()` : `value` est déprécié depuis Flutter 3.27.
    'color': color.toARGB32(),
  };

  factory Person.fromJson(Map<String, Object?> json) => Person(
    id: json['id']! as String,
    name: json['name']! as String,
    color: Color(json['color']! as int),
  );
}

class Project {
  const Project({
    required this.id,
    required this.key,
    required this.name,
    required this.milestoneName,
    required this.color,
  });

  final String id;

  /// Préfixe des références, ex. « ECH ».
  final String key;
  final String name;

  /// Jalon courant, affiché dans le sous-titre. Pas d'affectation par
  /// demande en V1 : la progression porte sur tout le projet.
  final String milestoneName;

  /// Pastille du projet dans le sélecteur, prise dans `T.projectPalette`.
  final Color color;

  Map<String, Object?> toJson() => {
    'id': id,
    'key': key,
    'name': name,
    'milestoneName': milestoneName,
    // `Color.toARGB32()` : `value` est déprécié depuis Flutter 3.27.
    'color': color.toARGB32(),
  };

  factory Project.fromJson(Map<String, Object?> json) => Project(
    id: json['id']! as String,
    key: json['key']! as String,
    name: json['name']! as String,
    milestoneName: json['milestoneName'] as String? ?? '',
    color: Color(json['color']! as int),
  );
}

class Request {
  const Request({
    required this.number,
    required this.projectId,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.requesterId,
    required this.assigneeId,
    required this.createdAt,
    this.priority = RequestPriority.medium,
    this.dueDate,
  });

  /// Identifie la demande dans son projet ; la référence affichée en dérive.
  final int number;

  /// Projet d'appartenance. La numérotation est propre à chaque projet :
  /// `ECH-58` et `ATL-3` coexistent.
  final String projectId;
  final String title;
  final String description;
  final RequestType type;
  final RequestStatus status;

  /// « Demandé par ».
  final String requesterId;

  /// « Intervenant » ; `null` = non assigné.
  final String? assigneeId;

  /// Sert au filtre par mois.
  final DateTime createdAt;

  final RequestPriority priority;

  /// Échéance, au jour près (heure à minuit) ; `null` = aucune.
  final DateTime? dueDate;

  /// En retard : échéance passée et demande pas encore faite.
  bool isOverdue(DateTime today) {
    final due = dueDate;
    if (due == null || status == RequestStatus.done) return false;
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  String reference(String projectKey) => '$projectKey-$number';

  Request copyWith({
    String? title,
    String? description,
    RequestType? type,
    RequestStatus? status,
    String? assigneeId,
    bool clearAssignee = false,
    RequestPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) => Request(
    number: number,
    projectId: projectId,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    status: status ?? this.status,
    requesterId: requesterId,
    assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
    createdAt: createdAt,
    priority: priority ?? this.priority,
    dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
  );

  Map<String, Object?> toJson() => {
    'number': number,
    'projectId': projectId,
    'title': title,
    'description': description,
    'type': type.name,
    'status': status.name,
    'requesterId': requesterId,
    'assigneeId': assigneeId,
    'createdAt': createdAt.toIso8601String(),
    'priority': priority.name,
    'dueDate': dueDate?.toIso8601String(),
  };

  /// Lève si un champ manque ou a le mauvais type ; `PrefsRepository`
  /// rattrape et repart des données d'exemple.
  factory Request.fromJson(Map<String, Object?> json) => Request(
    number: json['number']! as int,
    // Les demandes enregistrées en V1 n'ont pas de projet : elles sont
    // toutes d'Échéo, seul projet qui existait alors.
    projectId: json['projectId'] as String? ?? 'echeo',
    title: json['title']! as String,
    description: json['description']! as String,
    type: RequestType.values.byName(json['type']! as String),
    status: RequestStatus.values.byName(json['status']! as String),
    requesterId: json['requesterId']! as String,
    assigneeId: json['assigneeId'] as String?,
    // `voterIds`, s'il est encore là (votes retirés le 13/10), est ignoré.
    createdAt: DateTime.parse(json['createdAt']! as String),
    // Absents des données écrites avant le 13/10 : priorité moyenne, sans
    // échéance.
    priority: json['priority'] == null
        ? RequestPriority.medium
        : RequestPriority.values.byName(json['priority']! as String),
    dueDate: json['dueDate'] == null
        ? null
        : DateTime.parse(json['dueDate']! as String),
  );
}

/// Ce que la persistance échange en un bloc : les projets et leurs demandes.
/// Les deux voyagent ensemble — une demande sans son projet n'a pas de sens.
class ArdoiseSnapshot {
  const ArdoiseSnapshot({
    required this.projects,
    required this.requests,
    this.people,
    this.currentUserId,
  });

  final List<Project> projects;
  final List<Request> requests;

  /// `null` dans un document écrit avant que les personnes soient gérées :
  /// l'appelant retombe alors sur les données d'exemple. Pas de changement de
  /// clé, donc pas de migration — seulement des champs tolérés absents.
  final List<Person>? people;
  final String? currentUserId;

  Map<String, Object?> toJson() => {
    'projects': projects.map((p) => p.toJson()).toList(),
    'requests': requests.map((r) => r.toJson()).toList(),
    'people': people?.map((p) => p.toJson()).toList(),
    'currentUserId': currentUserId,
  };

  /// Lève sur un document mal formé ; `PrefsRepository` rattrape.
  factory ArdoiseSnapshot.fromJson(Map<String, Object?> json) =>
      ArdoiseSnapshot(
        projects: (json['projects']! as List)
            .cast<Map<String, Object?>>()
            .map(Project.fromJson)
            .toList(),
        requests: (json['requests']! as List)
            .cast<Map<String, Object?>>()
            .map(Request.fromJson)
            .toList(),
        people: (json['people'] as List?)
            ?.cast<Map<String, Object?>>()
            .map(Person.fromJson)
            .toList(),
        currentUserId: json['currentUserId'] as String?,
      );
}

// — Dates en français. Deux formats suffisent : pas de dépendance à `intl`. —

const _frMonths = <String>[
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];
const _frMonthsShort = <String>[
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// « 7 oct. »
String formatShortDate(DateTime date) =>
    '${date.day} ${_frMonthsShort[date.month - 1]}';

/// « octobre »
String formatMonthWord(DateTime date) => _frMonths[date.month - 1];

/// « oct. 2026 » — pour les barres étroites, où « Octobre 2026 » déborde.
String formatMonthLabelShort(DateTime date) =>
    '${_frMonthsShort[date.month - 1]} ${date.year}';

/// « Octobre 2026 »
String formatMonthLabel(DateTime date) {
  final word = formatMonthWord(date);
  return '${word[0].toUpperCase()}${word.substring(1)} ${date.year}';
}

/// « 09/10/2026 » — le format de saisie d'une échéance.
String formatNumericDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

/// Lit « 9/10/2026 », « 09/10/26 » ou « 2026-10-09 » ; `null` si la date
/// n'existe pas (« 31/02/2026 ») ou ne se lit pas.
DateTime? parseFrenchDate(String text) {
  final clean = text.trim();
  final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(clean);
  final fr = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2}|\d{4})$')
      .firstMatch(clean);
  int year;
  int month;
  int day;
  if (iso != null) {
    year = int.parse(iso.group(1)!);
    month = int.parse(iso.group(2)!);
    day = int.parse(iso.group(3)!);
  } else if (fr != null) {
    day = int.parse(fr.group(1)!);
    month = int.parse(fr.group(2)!);
    year = int.parse(fr.group(3)!);
    if (year < 100) year += 2000;
  } else {
    return null;
  }
  final date = DateTime(year, month, day);
  // `DateTime` normalise le 31/02 en 3/03 : on refuse plutôt que de deviner.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
