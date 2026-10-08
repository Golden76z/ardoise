import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'primitives.dart';

/// La carte de demande du prototype (`.card`) : fond = couleur du type, contour
/// encre, ombre décalée. Le pied s'adapte au groupement courant.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.store,
    required this.request,
    required this.onOpen,
  });

  final ArdoiseStore store;
  final Request request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final card = _card();
    // Le demandeur est un fait, pas un état : rien à déplacer dans ce mode.
    if (store.grouping == BoardGrouping.requester) return card;

    return Draggable<int>(
      data: request.number,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        type: MaterialType.transparency,
        child: Opacity(
          opacity: 0.9,
          child: Transform.rotate(
            angle: 0.02,
            // Rendu dans l'`Overlay`, hors de l'arbre : aucune contrainte
            // héritée, d'où la largeur explicite.
            child: SizedBox(width: T.columnMinWidth - 24, child: card),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _card() {
    final requester = store.personById(request.requesterId);
    final assignee = store.personById(request.assigneeId);
    // Seul endroit de l'UI qui a besoin du groupement : une colonne de statut
    // n'a pas à répéter le statut de chaque carte.
    final showStatus = store.grouping != BoardGrouping.status;
    final showAssignee = store.grouping != BoardGrouping.assignee;

    return InkOutline(
      radius: T.rCard,
      color: T.typeColor(request.type),
      shadow: T.cardShadow,
      padding: const EdgeInsets.all(T.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${request.reference(store.project.key)} · '
                  '${formatShortDate(request.createdAt)}',
                  style: TextStyles.meta,
                ),
              ),
              VoteButton(
                onToggle: () => store.toggleVote(request.number),
                votes: request.votes,
                voted: request.votedBy(store.currentUserId),
                title: request.title,
              ),
            ],
          ),
          const SizedBox(height: T.cardGap),
          Semantics(
            button: true,
            child: InkWell(
              onTap: onOpen,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(request.title, style: TextStyles.cardTitle),
              ),
            ),
          ),
          const SizedBox(height: T.cardGap),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RequesterPill(person: requester),
              if (showStatus) StatusPill(status: request.status),
              if (showAssignee)
                Tooltip(
                  message: 'Intervenant : ${assignee?.name ?? 'Non assigné'}',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('→ ', style: TextStyles.meta),
                      PersonAvatar(person: assignee, size: 28, dashed: true),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequesterPill extends StatelessWidget {
  const _RequesterPill({required this.person});

  final Person? person;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
    decoration: BoxDecoration(
      color: T.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PersonAvatar(person: person),
        const SizedBox(width: 6),
        Text(
          person?.name ?? 'Non assigné',
          style: TextStyles.meta.copyWith(
            fontWeight: FontWeight.w600,
            color: T.ink,
          ),
        ),
      ],
    ),
  );
}
