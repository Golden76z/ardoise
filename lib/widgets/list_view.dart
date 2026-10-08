import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'dashed.dart';
import 'primitives.dart';

/// La vue Liste : une recherche plein texte, puis une ligne par demande, tous
/// mois confondus — c'est sa raison d'être face au tableau filtré par mois.
class RequestListView extends StatelessWidget {
  const RequestListView({
    super.key,
    required this.store,
    required this.onOpenRequest,
  });

  final ChantierStore store;
  final void Function(int) onOpenRequest;

  @override
  Widget build(BuildContext context) {
    final requests = store.listRequests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La clé fait repartir le champ à vide quand le projet change :
        // `setCurrentProject` oublie la recherche, le champ doit suivre.
        _SearchField(key: ValueKey(store.currentProjectId), store: store),
        const SizedBox(height: 14),
        if (requests.isEmpty)
          _EmptyList(store: store)
        else
          for (final request in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: T.cardGap),
              child: _ListRow(
                store: store,
                request: request,
                onOpen: () => onOpenRequest(request.number),
              ),
            ),
      ],
    );
  }
}

/// `StatefulWidget` pour garder le `TextEditingController` local : reconstruire
/// le champ depuis le store à chaque frappe perdrait le curseur. `onChanged`
/// plutôt qu'un écouteur sur le contrôleur : vider le champ par programme ne
/// doit pas repartir dans le store.
class _SearchField extends StatefulWidget {
  const _SearchField({super.key, required this.store});

  final ChantierStore store;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(
    text: widget.store.searchQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.store.setSearchQuery('');
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('list-search'),
    controller: _controller,
    style: TextStyles.body.copyWith(fontSize: 16),
    onChanged: widget.store.setSearchQuery,
    decoration: InputDecoration(
      hintText: 'Un mot du titre, de la description, ou une référence',
      hintStyle: TextStyles.sub,
      filled: true,
      fillColor: T.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      prefixIcon: const Padding(
        padding: EdgeInsets.only(left: 16, right: 10),
        child: Center(
          widthFactor: 1,
          child: Text('Rechercher', style: TextStyles.label),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(),
      suffixIcon: widget.store.searchQuery.isEmpty
          ? null
          : Semantics(
              button: true,
              label: 'Effacer la recherche',
              child: InkWell(
                onTap: _clear,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: ExcludeSemantics(
                    child: Center(
                      child: Text(
                        '×',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: T.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      border: _border(T.ink),
      enabledBorder: _border(T.ink),
      focusedBorder: _border(T.accent),
    ),
  );

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: color, width: T.borderWidth),
  );
}

/// Une liste vide se dit, sinon on croit à une panne.
class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) {
    final query = store.searchQuery.trim();
    return DashedBorder(
      radius: 16,
      color: T.line,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Center(
          child: Text(
            query.isEmpty
                ? 'Aucune demande dans ce projet.'
                : 'Aucune demande ne correspond à « $query ».',
            style: TextStyles.sub,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.store,
    required this.request,
    required this.onOpen,
  });

  final ChantierStore store;
  final Request request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(T.rCard),
      child: InkOutline(
        radius: T.rCard,
        color: T.typeColor(request.type),
        shadow: T.cardShadow,
        padding: const EdgeInsets.symmetric(
          horizontal: T.cardPadding,
          vertical: 10,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final reference = SizedBox(
              width: 120,
              child: Text(
                '${request.reference(store.project.key)} · '
                '${formatShortDate(request.createdAt)}',
                style: TextStyles.meta,
              ),
            );
            final title = Text(
              request.title,
              style: TextStyles.cardTitle,
              overflow: TextOverflow.ellipsis,
            );
            final meta = <Widget>[
              PersonAvatar(person: store.personById(request.requesterId)),
              StatusPill(status: request.status),
              Tooltip(
                message:
                    'Intervenant : '
                    '${store.personById(request.assigneeId)?.name ?? 'Non assigné'}',
                child: PersonAvatar(
                  person: store.personById(request.assigneeId),
                  size: 28,
                  dashed: true,
                ),
              ),
              VoteButton(
                onToggle: () => store.toggleVote(request.number),
                votes: request.votes,
                voted: request.votedBy(store.currentUserId),
                title: request.title,
              ),
            ];

            // Au large, une `Row` : les pastilles s'alignent d'une ligne à
            // l'autre, et c'est cet alignement qui rend une liste lisible d'un
            // coup d'œil. À l'étroit, elles passent à la ligne plutôt que de
            // déborder — le tableau s'en sort par un défilement horizontal,
            // une liste doit rester lisible sur place.
            if (constraints.maxWidth >= 560) {
              return Row(
                children: [
                  reference,
                  const SizedBox(width: 10),
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  for (final widget in meta) ...[
                    widget,
                    if (widget != meta.last) const SizedBox(width: 10),
                  ],
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    reference,
                    const SizedBox(width: 10),
                    Expanded(child: title),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 8, children: meta),
              ],
            );
          },
        ),
      ),
    ),
  );
}
