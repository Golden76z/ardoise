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
    this.status,
    this.dotColor,
    this.person,
    this.countAtEnd = false,
    this.isUnassigned = false,
  });

  final String title;
  final List<Request> requests;

  /// Mode « Statut » : le statut que la colonne représente ; `null` ailleurs.
  /// Le glisser-déposer le lit — retrouver le statut par son libellé serait
  /// fragile.
  final RequestStatus? status;

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
class ArdoiseStore extends ChangeNotifier {
  ArdoiseStore({required ArdoiseRepository repository, DateTime? today})
    // Un paramètre nommé ne peut pas être privé : le champ ne peut donc pas
    // être initialisé par un paramètre initialisateur.
    // ignore: prefer_initializing_formals
    : _repository = repository,
      // L'app reste ouverte des heures : l'horloge se relit à chaque usage,
      // sinon une demande créée après minuit porte la date de la veille.
      // `today` fige le temps pour les tests, et sert de mois initial.
      _now = today == null ? DateTime.now : (() => today),
      _visibleMonth = _monthOf(today ?? DateTime.now());

  final ArdoiseRepository _repository;
  final DateTime Function() _now;

  List<Person> _people = const [];
  String _currentUserId = seedCurrentUserId;

  List<Person> get people => List.unmodifiable(_people);

  /// Qui je suis : le demandeur de toute demande que je crée, et le votant
  /// que bascule chaque ▲.
  String get currentUserId => _currentUserId;

  List<Project> _projects = const [];
  String _currentProjectId = '';
  List<Request> _requests = const [];
  ViewMode _viewMode = ViewMode.board;
  String _searchQuery = '';
  ListSort _listSort = ListSort.recent;
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
  List<Project> get projects => List.unmodifiable(_projects);
  String get currentProjectId => _currentProjectId;
  ViewMode get viewMode => _viewMode;
  String get searchQuery => _searchQuery;
  ListSort get listSort => _listSort;

  /// Le projet courant. Le store garantit qu'il en existe toujours un.
  Project get project => _projects.firstWhere(
    (p) => p.id == _currentProjectId,
    orElse: () => _projects.first,
  );

  /// Non nul quand la dernière écriture a échoué : l'UI doit le montrer.
  /// Une sauvegarde perdue en silence, c'est du travail perdu.
  String? get saveError => _saveError;

  Future<void> init() async {
    // Quoi qu'il arrive, on sort de l'état de chargement : un dépôt qui lève
    // ne doit pas laisser l'utilisateur devant un indicateur qui tourne.
    try {
      final snapshot = await _repository.load();
      _people = snapshot?.people ?? seedPeople;
      _currentUserId = snapshot?.currentUserId ?? seedCurrentUserId;
      final failure = _repository.lastLoadError;
      if (failure != null) {
        // Des données existent peut-être : le dire, sinon la première
        // écriture remplace du vrai travail par des données d'exemple.
        _saveError = 'Lecture des données impossible ($failure).';
      }
      _projects = snapshot?.projects ?? seedProjects;
      _requests = snapshot?.requests ?? seedRequests;
      // Sans projet ni personne, `project` et `currentUserId` n'ont rien à
      // servir : on repart des données d'exemple plutôt que d'un écran mort.
      if (_projects.isEmpty) _projects = seedProjects;
      if (_people.isEmpty) _people = seedPeople;
    } on Object catch (error) {
      _projects = seedProjects;
      _requests = seedRequests;
      _people = seedPeople;
      _currentUserId = seedCurrentUserId;
      _saveError = 'Données locales illisibles ($error) : données d’exemple.';
    }
    _currentProjectId = _projects.first.id;
    if (!_people.any((p) => p.id == _currentUserId)) {
      _currentUserId = _people.first.id;
    }
    _loading = false;
    notifyListeners();
  }

  // — Lecture —

  Person? personById(String? id) {
    if (id == null) return null;
    for (final person in _people) {
      if (person.id == id) return person;
    }
    return null;
  }

  /// Le numéro n'identifie une demande qu'**au sein d'un projet** : deux
  /// projets ont chacun leur n°1. Toute lecture et toute écriture se font
  /// donc dans le projet courant, jamais sur `_requests` entier.
  Request? requestByNumber(int number) {
    for (final request in _projectRequests) {
      if (request.number == number) return request;
    }
    return null;
  }

  /// Les demandes du projet courant. Point de passage obligé : rien d'autre
  /// ne lit `_requests` directement, sauf la persistance et `requestCountOf`.
  Iterable<Request> get _projectRequests =>
      _requests.where((r) => r.projectId == _currentProjectId);

  /// Les demandes du mois affiché, tous types confondus : c'est la base des
  /// compteurs de puces, qui ne doivent pas suivre le filtre de type.
  Iterable<Request> get _monthRequests => _projectRequests.where(
    (r) =>
        r.createdAt.year == _visibleMonth.year &&
        r.createdAt.month == _visibleMonth.month,
  );

  int requestCountOf(String projectId) =>
      _requests.where((r) => r.projectId == projectId).length;

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
    final all = _projectRequests.toList();
    if (all.isEmpty) return 0;
    final done = all.where((r) => r.status == RequestStatus.done).length;
    return (done * 100 / all.length).round();
  }

  String get subtitle {
    final count = visibleRequests.length;
    final plural = count > 1 ? 's' : '';
    // Un projet créé à la main n'a pas de jalon : « Jalon  · » serait du bruit.
    final milestone = project.milestoneName.trim();
    return '$count demande$plural en ${formatMonthWord(_visibleMonth)}'
        '${milestone.isEmpty ? '' : ' · Jalon $milestone'}'
        ' · $milestoneProgressPercent %';
  }

  List<BoardColumn> get columns {
    final visible = visibleRequests;

    if (_grouping == BoardGrouping.status) {
      return [
        for (final status in RequestStatus.values)
          BoardColumn(
            title: status.label,
            status: status,
            dotColor: T.statusColor(status),
            requests: visible.where((r) => r.status == status).toList(),
          ),
      ];
    }

    final byRequester = _grouping == BoardGrouping.requester;
    return [
      for (final person in _people.where((p) => isPersonShown(p.id)))
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

  /// Tous mois confondus — c'est sa raison d'être : retrouver une demande que
  /// le tableau, filtré par mois, ne montre plus.
  List<Request> get listRequests {
    final query = _searchQuery.trim().toLowerCase();
    final found = _projectRequests.where((r) {
      if (!_activeTypes.contains(r.type)) return false;
      if (query.isEmpty) return true;
      return r.title.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query) ||
          r.reference(project.key).toLowerCase().contains(query);
    }).toList();

    found.sort(switch (_listSort) {
      ListSort.recent => (a, b) => b.createdAt.compareTo(a.createdAt),
      ListSort.votes => (a, b) => b.votes.compareTo(a.votes),
      // L'ordre de l'enum est l'ordre du flux de travail : à faire → fait.
      ListSort.status => (a, b) => a.status.index.compareTo(b.status.index),
    });
    return found;
  }

  // — Écriture —

  void setViewMode(ViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setListSort(ListSort sort) {
    _listSort = sort;
    notifyListeners();
  }

  void setCurrentProject(String id) {
    // Un id inconnu laisserait `project` retomber sur `orElse` : l'en-tête
    // montrerait un projet, les écritures en viseraient un autre.
    if (!_projects.any((p) => p.id == id)) return;
    if (_currentProjectId == id) return;
    _currentProjectId = id;
    // Une recherche en cours n'a pas de sens dans un autre projet.
    _searchQuery = '';
    notifyListeners();
  }

  /// Rend `null` si le projet est créé, sinon le motif du refus — à afficher.
  /// La clé identifie les demandes (`ECH-42`) : vide ou en doublon, les
  /// références cesseraient d'identifier.
  String? createProject({
    required String name,
    required String key,
    required Color color,
  }) {
    final cleanName = name.trim();
    final cleanKey = key.trim().toUpperCase();
    if (cleanName.isEmpty) return 'Le nom est obligatoire.';
    if (cleanKey.isEmpty) return 'La clé est obligatoire.';
    if (cleanKey.length > 5) return 'La clé fait 5 caractères au plus.';
    if (_projects.any((p) => p.key.toUpperCase() == cleanKey)) {
      return 'La clé « $cleanKey » est déjà prise.';
    }
    _projects = [
      ..._projects,
      Project(
        id: '${cleanKey.toLowerCase()}-${_now().microsecondsSinceEpoch}',
        key: cleanKey,
        name: cleanName,
        milestoneName: '',
        color: color,
      ),
    ];
    _persist();
    notifyListeners();
    return null;
  }

  /// Rend `null` si le projet est supprimé, sinon le motif du refus.
  /// Emporte ses demandes — l'appelant doit avoir fait confirmer.
  String? deleteProject(String id) {
    if (!_projects.any((p) => p.id == id)) return 'Ce projet n’existe pas.';
    if (_projects.length <= 1) {
      return 'Impossible de supprimer le dernier projet.';
    }
    _projects = _projects.where((p) => p.id != id).toList();
    _requests = _requests.where((r) => r.projectId != id).toList();
    if (_currentProjectId == id) {
      _currentProjectId = _projects.first.id;
      _searchQuery = '';
    }
    _persist();
    notifyListeners();
    return null;
  }

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
      // Par projet : ATL-3 et ECH-58 coexistent.
      number:
          _projectRequests.fold(
            0,
            (max, r) => r.number > max ? r.number : max,
          ) +
          1,
      projectId: _currentProjectId,
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

  // — Les personnes —
  //
  // Mêmes règles que les projets : on rend `null` quand c'est fait, sinon le
  // motif du refus, à afficher. Un identifiant ne change jamais — c'est lui
  // que portent les demandes.

  String? createPerson({required String name}) {
    final clean = name.trim();
    final refus = _checkName(clean);
    if (refus != null) return refus;

    _people = [
      ..._people,
      Person(
        id: 'p-${_now().microsecondsSinceEpoch}',
        name: clean,
        // On déroule la palette : deux voisins n'ont pas la même couleur.
        color: T.personPalette[_people.length % T.personPalette.length],
      ),
    ];
    _persist();
    notifyListeners();
    return null;
  }

  String? renamePerson(String id, String name) {
    if (!_people.any((p) => p.id == id)) return 'Cette personne n’existe pas.';
    final clean = name.trim();
    final refus = _checkName(clean, exceptId: id);
    if (refus != null) return refus;

    _people = [
      for (final person in _people)
        if (person.id == id) person.copyWith(name: clean) else person,
    ];
    _persist();
    notifyListeners();
    return null;
  }

  /// Refusé quand la personne est **demandeuse** : une demande sans demandeur
  /// n'a pas de sens. Sinon elle est détachée des intervenants et des votes,
  /// puis supprimée.
  String? deletePerson(String id) {
    if (!_people.any((p) => p.id == id)) return 'Cette personne n’existe pas.';
    if (id == _currentUserId) {
      return 'Vous ne pouvez pas vous supprimer. Désignez d’abord quelqu’un '
          'd’autre comme vous.';
    }
    if (_people.length <= 1) {
      return 'Impossible de supprimer la dernière personne.';
    }

    final demandes = _requests.where((r) => r.requesterId == id).length;
    if (demandes > 0) {
      final pluriel = demandes > 1 ? 's' : '';
      return '$demandes demande$pluriel ${demandes > 1 ? 'ont' : 'a'} été '
          'faite$pluriel par cette personne. Réattribuez-les ou supprimez-les '
          'avant de la retirer.';
    }

    _requests = [
      for (final request in _requests)
        if (request.assigneeId == id || request.voterIds.contains(id))
          request.copyWith(
            clearAssignee: request.assigneeId == id,
            voterIds: {...request.voterIds}..remove(id),
          )
        else
          request,
    ];
    _people = _people.where((p) => p.id != id).toList();
    _hiddenPersonIds.remove(id);
    _persist();
    notifyListeners();
    return null;
  }

  void setCurrentUser(String id) {
    // Un id inconnu laisserait les nouvelles demandes sans demandeur valide.
    if (!_people.any((p) => p.id == id)) return;
    if (_currentUserId == id) return;
    _currentUserId = id;
    _persist();
    notifyListeners();
  }

  /// Table rase. Laisse **un** projet et **une** personne, tous deux
  /// renommables : sans eux, il n'y a plus ni projet courant ni demandeur, et
  /// l'app n'a rien à afficher.
  void clearAll() {
    _people = [
      Person(
        id: 'p-${_now().microsecondsSinceEpoch}',
        name: 'Moi',
        color: T.personPalette.first,
      ),
    ];
    _currentUserId = _people.first.id;
    _projects = [
      Project(
        id: 'projet-${_now().microsecondsSinceEpoch}',
        key: 'PRJ',
        name: 'Mon projet',
        milestoneName: '',
        color: T.projectPalette.first,
      ),
    ];
    _currentProjectId = _projects.first.id;
    _requests = const [];
    _hiddenPersonIds.clear();
    _searchQuery = '';
    _persist();
    notifyListeners();
  }

  /// Un nom vide n'identifie personne, et deux homonymes rendent les colonnes
  /// « Intervenant » et « Demandeur » illisibles.
  String? _checkName(String clean, {String? exceptId}) {
    if (clean.isEmpty) return 'Le nom est obligatoire.';
    final collision = _people.any(
      (p) => p.id != exceptId && p.name.toLowerCase() == clean.toLowerCase(),
    );
    return collision ? 'Quelqu’un porte déjà ce nom.' : null;
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

  /// La clé d'écriture est le couple (projet courant, numéro) — sur le seul
  /// numéro, un changement de statut dans un projet en modifierait un autre.
  void _mutate(int number, Request Function(Request) change) {
    _requests = [
      for (final request in _requests)
        if (request.number == number && request.projectId == _currentProjectId)
          change(request)
        else
          request,
    ];
    _persist();
    notifyListeners();
  }

  void _persist() {
    _repository
        .save(
          ArdoiseSnapshot(
            projects: _projects,
            requests: _requests,
            people: _people,
            currentUserId: _currentUserId,
          ),
        )
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
