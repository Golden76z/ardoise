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

enum BoardGrouping {
  status('Statut'),
  assignee('Intervenant'),
  requester('Demandeur');

  const BoardGrouping(this.label);
  final String label;
}

class Person {
  const Person({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;

  String get initial => name.substring(0, 1).toUpperCase();
}

class Project {
  const Project({
    required this.id,
    required this.key,
    required this.name,
    required this.milestoneName,
  });

  final String id;

  /// Préfixe des références, ex. « ECH ».
  final String key;
  final String name;

  /// Jalon courant, affiché dans le sous-titre. Pas d'affectation par
  /// demande en V1 : la progression porte sur tout le projet.
  final String milestoneName;
}

class Request {
  const Request({
    required this.number,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.requesterId,
    required this.assigneeId,
    required this.createdAt,
    required this.voterIds,
  });

  /// Identifie la demande ; la référence affichée en dérive.
  final int number;
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

  /// Un vote par personne (handoff §1) : le compte en dérive.
  final Set<String> voterIds;

  int get votes => voterIds.length;

  bool votedBy(String personId) => voterIds.contains(personId);

  String reference(String projectKey) => '$projectKey-$number';

  Request copyWith({
    String? title,
    String? description,
    RequestType? type,
    RequestStatus? status,
    String? assigneeId,
    bool clearAssignee = false,
    Set<String>? voterIds,
  }) => Request(
    number: number,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    status: status ?? this.status,
    requesterId: requesterId,
    assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
    createdAt: createdAt,
    voterIds: voterIds ?? this.voterIds,
  );

  Map<String, Object?> toJson() => {
    'number': number,
    'title': title,
    'description': description,
    'type': type.name,
    'status': status.name,
    'requesterId': requesterId,
    'assigneeId': assigneeId,
    'createdAt': createdAt.toIso8601String(),
    'voterIds': voterIds.toList(),
  };

  /// Lève si un champ manque ou a le mauvais type ; `PrefsRepository`
  /// rattrape et repart des données d'exemple.
  factory Request.fromJson(Map<String, Object?> json) => Request(
    number: json['number']! as int,
    title: json['title']! as String,
    description: json['description']! as String,
    type: RequestType.values.byName(json['type']! as String),
    status: RequestStatus.values.byName(json['status']! as String),
    requesterId: json['requesterId']! as String,
    assigneeId: json['assigneeId'] as String?,
    createdAt: DateTime.parse(json['createdAt']! as String),
    voterIds: (json['voterIds']! as List).cast<String>().toSet(),
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

/// « Octobre 2026 »
String formatMonthLabel(DateTime date) {
  final word = formatMonthWord(date);
  return '${word[0].toUpperCase()}${word.substring(1)} ${date.year}';
}
