import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../theme/tokens.dart';
import 'repository.dart';
import 'seed.dart';

/// Une colonne du tableau. Le store la construit ; l'UI ne fait que l'afficher.
class BoardColumn {
  const BoardColumn({
    required this.title,
    required this.requests,
    this.dotColor,
    this.person,
    this.countAtEnd = false,
    this.isUnassigned = false,
  });

  final String title;
  final List<Request> requests;

  /// Mode « Statut » : la pastille de couleur devant le titre.
  final Color? dotColor;

  /// Mode « Intervenant » / « Demandeur » : l'avatar devant le titre.
  final Person? person;

  /// En mode personne, le compteur est poussé à droite (prototype `.push`).
  final bool countAtEnd;

  final bool isUnassigned;
}

/// Tout l'état de l'app. Un seul notifieur : le tableau est une vue unique,
/// et le découper en plusieurs blocs ne ferait que multiplier les
/// synchronisations.
class ChantierStore extends ChangeNotifier {
  ChantierStore({required ChantierRepository repository, DateTime? today})
    // Un paramètre nommé ne peut pas être privé : le champ ne peut donc pas
    // être initialisé par un paramètre initialisateur.
    // ignore: prefer_initializing_formals
    : _repository = repository,
      // L'app reste ouverte des heures : l'horloge se relit à chaque usage,
      // sinon une demande créée après minuit porte la date de la veille.
      // `today` fige le temps pour les tests, et sert de mois initial.
      _now = today == null ? DateTime.now : (() => today),
      _visibleMonth = _monthOf(today ?? DateTime.now());

  final ChantierRepository _repository;
  final DateTime Function() _now;

  final Project project = seedProject;
  final List<Person> people = seedPeople;
  final String currentUserId = seedCurrentUserId;

  List<Request> _requests = const [];
  BoardGrouping _grouping = BoardGrouping.status;
  DateTime _visibleMonth;
  final Set<RequestType> _activeTypes = {...RequestType.values};
  final Set<String> _hiddenPersonIds = {};
  bool _loading = true;
  String? _saveError;

  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  bool get loading => _loading;
  BoardGrouping get grouping => _grouping;
  DateTime get visibleMonth => _visibleMonth;

  /// Non nul quand la dernière écriture a échoué : l'UI doit le montrer.
  /// Une sauvegarde perdue en silence, c'est du travail perdu.
  String? get saveError => _saveError;

  Future<void> init() async {
    // Quoi qu'il arrive, on sort de l'état de chargement : un dépôt qui lève
    // ne doit pas laisser l'utilisateur devant un indicateur qui tourne.
    try {
      _requests = await _repository.load() ?? seedRequests;
    } on Object catch (error) {
      _requests = seedRequests;
      _saveError = 'Données locales illisibles ($error) : données d’exemple.';
    }
    _loading = false;
    notifyListeners();
  }

  // — Lecture —

  Person? personById(String? id) {
    if (id == null) return null;
    for (final person in people) {
      if (person.id == id) return person;
    }
    return null;
  }

  Request? requestByNumber(int number) {
    for (final request in _requests) {
      if (request.number == number) return request;
    }
    return null;
  }

  /// Les demandes du mois affiché, tous types confondus : c'est la base des
  /// compteurs de puces, qui ne doivent pas suivre le filtre de type.
  Iterable<Request> get _monthRequests => _requests.where(
    (r) =>
        r.createdAt.year == _visibleMonth.year &&
        r.createdAt.month == _visibleMonth.month,
  );

  List<Request> get visibleRequests => _monthRequests
      .where((r) => _activeTypes.contains(r.type))
      .toList(growable: false);

  int countOfType(RequestType type) =>
      _monthRequests.where((r) => r.type == type).length;

  bool isTypeActive(RequestType type) => _activeTypes.contains(type);

  bool isPersonShown(String personId) => !_hiddenPersonIds.contains(personId);

  /// Progression du jalon sur tout le projet : pas d'affectation par demande
  /// en V1 (hors périmètre, handoff §4).
  int get milestoneProgressPercent {
    if (_requests.isEmpty) return 0;
    final done = _requests.where((r) => r.status == RequestStatus.done).length;
    return (done * 100 / _requests.length).round();
  }

  String get subtitle {
    final count = visibleRequests.length;
    final plural = count > 1 ? 's' : '';
    return '$count demande$plural en ${formatMonthWord(_visibleMonth)}'
        ' · Jalon ${project.milestoneName}'
        ' · $milestoneProgressPercent %';
  }

  List<BoardColumn> get columns {
    final visible = visibleRequests;

    if (_grouping == BoardGrouping.status) {
      return [
        for (final status in RequestStatus.values)
          BoardColumn(
            title: status.label,
            dotColor: T.statusColor(status),
            requests: visible.where((r) => r.status == status).toList(),
          ),
      ];
    }

    final byRequester = _grouping == BoardGrouping.requester;
    return [
      for (final person in people.where((p) => isPersonShown(p.id)))
        BoardColumn(
          title: person.name,
          person: person,
          countAtEnd: true,
          requests: visible
              .where(
                (r) =>
                    (byRequester ? r.requesterId : r.assigneeId) == person.id,
              )
              .toList(),
        ),
      // Une demande sans intervenant doit rester visible ; une demande sans
      // demandeur n'existe pas.
      if (!byRequester)
        BoardColumn(
          title: 'Non assigné',
          countAtEnd: true,
          isUnassigned: true,
          requests: visible.where((r) => r.assigneeId == null).toList(),
        ),
    ];
  }

  // — Écriture —

  void setGrouping(BoardGrouping grouping) {
    _grouping = grouping;
    notifyListeners();
  }

  void toggleType(RequestType type) {
    if (!_activeTypes.remove(type)) _activeTypes.add(type);
    notifyListeners();
  }

  void togglePerson(String personId) {
    if (!_hiddenPersonIds.remove(personId)) _hiddenPersonIds.add(personId);
    notifyListeners();
  }

  /// Navigation libre : `DateTime` normalise le mois 13 en janvier suivant.
  void shiftMonth(int delta) {
    _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    notifyListeners();
  }

  void toggleVote(int number) => _mutate(number, (request) {
    final voters = {...request.voterIds};
    if (!voters.remove(currentUserId)) voters.add(currentUserId);
    return request.copyWith(voterIds: voters);
  });

  void setStatus(int number, RequestStatus status) =>
      _mutate(number, (request) => request.copyWith(status: status));

  void setAssignee(int number, String? personId) => _mutate(
    number,
    (request) =>
        request.copyWith(assigneeId: personId, clearAssignee: personId == null),
  );

  /// Rend `null` si le titre est vide — l'UI désactive le bouton, ceci est le
  /// garde-fou côté données.
  Request? createRequest({
    required String title,
    required RequestType type,
    String? assigneeId,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;

    final request = Request(
      number:
          _requests.fold(0, (max, r) => r.number > max ? r.number : max) + 1,
      title: trimmed,
      description: '',
      type: type,
      status: RequestStatus.todo,
      requesterId: currentUserId,
      assigneeId: assigneeId,
      createdAt: _creationDate(),
      voterIds: const {},
    );
    _requests = [request, ..._requests];
    _persist();
    notifyListeners();
    return request;
  }

  void dismissSaveError() {
    _saveError = null;
    notifyListeners();
  }

  /// La demande naît dans le mois affiché (comportement du prototype) :
  /// aujourd'hui si c'est le mois courant, sinon son premier jour.
  DateTime _creationDate() {
    final now = _now();
    return now.year == _visibleMonth.year && now.month == _visibleMonth.month
        ? now
        : _visibleMonth;
  }

  void _mutate(int number, Request Function(Request) change) {
    _requests = [
      for (final request in _requests)
        if (request.number == number) change(request) else request,
    ];
    _persist();
    notifyListeners();
  }

  void _persist() {
    _repository
        .save(_requests)
        .then(
          (_) {
            if (_saveError == null) return;
            _saveError = null;
            notifyListeners();
          },
          onError: (Object error) {
            _saveError = 'Enregistrement impossible : $error';
            notifyListeners();
          },
        );
  }
}
