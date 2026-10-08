import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'dashed.dart';
import 'primitives.dart';

/// `showGeneralDialog` donne gratuitement le fond translucide, la fermeture au
/// clic dehors, Échap et le piège à focus.
Future<void> showRequestDetail(
  BuildContext context,
  ArdoiseStore store,
  int number,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Fermer le détail',
  barrierColor: T.backdrop,
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (_, _, _) => Align(
    alignment: Alignment.centerRight,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final request = store.requestByNumber(number);
        // La demande a pu disparaître : on n'affiche rien plutôt que de
        // planter.
        if (request == null) return const SizedBox.shrink();
        return _Drawer(store: store, request: request);
      },
    ),
  ),
  transitionBuilder: (context, animation, _, child) => SlideTransition(
    position: Tween(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
    child: child,
  ),
);

class _Drawer extends StatelessWidget {
  const _Drawer({required this.store, required this.request});

  final ArdoiseStore store;
  final Request request;

  @override
  Widget build(BuildContext context) {
    final requester = store.personById(request.requesterId);
    final voters = request.voterIds
        .map(store.personById)
        .whereType<Person>()
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(16),
      // Pleine hauteur comme `top:16; bottom:16` du prototype ; le contenu
      // défile à l'intérieur.
      child: SizedBox(
        width: T.drawerWidth,
        height: double.infinity,
        // Un panneau de dialogue n'a pas de `Material` ancêtre : les `InkWell`
        // en réclament un.
        child: Material(
          type: MaterialType.transparency,
          child: InkOutline(
            radius: T.rPanel,
            color: T.surface,
            shadow: T.panelShadow,
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkOutline(
                        radius: T.rSmallChip,
                        color: T.typeColor(request.type),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        child: Text(
                          request.type.label,
                          style: TextStyles.bold800.copyWith(
                            fontSize: T.fsMeta,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${request.reference(store.project.key)} · '
                          '${formatShortDate(request.createdAt)}',
                          style: TextStyles.sub,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Fermer',
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          customBorder: const CircleBorder(),
                          child: InkOutline(
                            radius: 18,
                            color: T.bg,
                            borderColor: T.line,
                            child: const SizedBox(
                              width: 36 - 2 * T.borderWidth,
                              height: 36 - 2 * T.borderWidth,
                              child: Center(child: Text('✕')),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(request.title, style: TextStyles.panelTitle),
                  if (request.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(request.description, style: TextStyles.description),
                  ],
                  const SizedBox(height: 18),
                  _Field(
                    label: 'Statut',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final status in RequestStatus.values)
                          ChoicePill(
                            label: status.label,
                            selected: request.status == status,
                            fill: T.statusColor(status),
                            onTap: () =>
                                store.setStatus(request.number, status),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Field(
                    label: 'Intervenant',
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final person in store.people)
                          ChoicePill(
                            label: person.name,
                            avatar: person,
                            selected: request.assigneeId == person.id,
                            fill: T.accentSoft,
                            onTap: () =>
                                store.setAssignee(request.number, person.id),
                          ),
                        ChoicePill(
                          label: 'Personne',
                          showAvatar: true,
                          selected: request.assigneeId == null,
                          fill: T.accentSoft,
                          onTap: () => store.setAssignee(request.number, null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const DashedDivider(),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Demandé par', style: TextStyles.label),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PersonAvatar(person: requester, size: 28),
                              const SizedBox(width: 6),
                              Text(
                                requester?.name ?? '—',
                                style: TextStyles.body,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AvatarStack(people: voters),
                          const SizedBox(width: 10),
                          _BigVote(store: store, request: request),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyles.label),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class _BigVote extends StatelessWidget {
  const _BigVote({required this.store, required this.request});

  final ArdoiseStore store;
  final Request request;

  @override
  Widget build(BuildContext context) {
    final voted = request.votedBy(store.currentUserId);
    return Semantics(
      button: true,
      selected: voted,
      label: voted ? 'Retirer mon vote' : 'Voter',
      child: InkWell(
        onTap: () => store.toggleVote(request.number),
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 44,
          child: InkOutline(
            radius: 22,
            color: T.accentSoft,
            shadow: const [
              BoxShadow(color: T.shadowOffset, offset: Offset(2, 2)),
            ],
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(
                '▲ ${request.votes} vote${request.votes > 1 ? 's' : ''}',
                style: TextStyles.bold800.copyWith(
                  color: T.accentInk,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
