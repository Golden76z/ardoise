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

  final ChantierStore store;
  final Request request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
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
              _VoteButton(store: store, request: request),
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
              if (showStatus) _StatusPill(status: request.status),
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

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.store, required this.request});

  final ChantierStore store;
  final Request request;

  @override
  Widget build(BuildContext context) {
    final voted = request.votedBy(store.currentUserId);
    return Semantics(
      button: true,
      selected: voted,
      label: voted
          ? 'Retirer mon vote sur ${request.title}'
          : 'Voter pour ${request.title}',
      child: InkWell(
        onTap: () => store.toggleVote(request.number),
        borderRadius: BorderRadius.circular(T.rSmallChip),
        child: InkOutline(
          radius: T.rSmallChip,
          color: voted ? T.accentSoft : T.surface,
          borderColor: voted ? T.ink : T.line,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: SizedBox(
            height: 28 - 2 * T.borderWidth,
            child: Center(
              widthFactor: 1,
              child: Text(
                '▲ ${request.votes}',
                style: TextStyles.bold800.copyWith(color: T.accentInk),
              ),
            ),
          ),
        ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) => InkOutline(
    radius: T.rSmallChip + 1,
    color: T.statusColor(status),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: SizedBox(
      height: 26 - 2 * T.borderWidth,
      // Sans `widthFactor`, `Center` s'étire à toute la largeur sous les
      // contraintes lâches du `Wrap` du pied de carte.
      child: Center(
        widthFactor: 1,
        child: Text(
          status.label,
          style: TextStyles.bold800.copyWith(fontSize: T.fsTiny),
        ),
      ),
    ),
  );
}
