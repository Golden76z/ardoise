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

    return Padding(
      padding: const EdgeInsets.all(16),
      // Le tiroir se cale sur son contenu et ne s'étire que s'il déborde :
      // forcé en pleine hauteur, il laissait un grand vide sous le pied sur
      // les demandes courtes. Le défilement interne prend le relais au-delà.
      child: SizedBox(
        width: T.drawerWidth,
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
                  const SizedBox(height: 8),
                  // Clé par demande : un brouillon ne passe pas d'une demande
                  // à l'autre.
                  _DescriptionEditor(
                    key: ValueKey(request.number),
                    store: store,
                    request: request,
                  ),
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
                  _Field(
                    label: 'Demandé par',
                    child: Row(
                      children: [
                        PersonAvatar(person: requester, size: 28),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            requester?.name ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.body,
                          ),
                        ),
                      ],
                    ),
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

/// La description : lue telle quelle, modifiée sur place. Rien n'est écrit
/// avant « Enregistrer » — dans le vault, chaque écriture est un changement
/// de note.
class _DescriptionEditor extends StatefulWidget {
  const _DescriptionEditor({
    super.key,
    required this.store,
    required this.request,
  });

  final ArdoiseStore store;
  final Request request;

  @override
  State<_DescriptionEditor> createState() => _DescriptionEditorState();
}

class _DescriptionEditorState extends State<_DescriptionEditor> {
  TextEditingController? _draft;

  @override
  void dispose() {
    _draft?.dispose();
    super.dispose();
  }

  void _edit() => setState(
    () => _draft = TextEditingController(text: widget.request.description),
  );

  void _close() {
    final draft = _draft;
    setState(() => _draft = null);
    draft?.dispose();
  }

  void _save() {
    widget.store.setDescription(widget.request.number, _draft!.text);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    if (draft != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: draft,
            autofocus: true,
            minLines: 3,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            style: TextStyles.body,
            decoration: inkInputDecoration(
              hint: 'Contexte, étapes pour reproduire, idée de solution…',
            ).copyWith(labelText: 'Description'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: PillButton(
                  label: 'Annuler',
                  style: PillStyle.ghost,
                  height: 36,
                  onPressed: _close,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: PillButton(
                  label: 'Enregistrer',
                  height: 36,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final description = widget.request.description;
    if (description.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: PillButton(
          label: '+ Ajouter une description',
          style: PillStyle.ghost,
          height: 34,
          onPressed: _edit,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(description, style: TextStyles.description),
        const SizedBox(height: 6),
        PillButton(
          label: 'Modifier la description',
          style: PillStyle.ghost,
          height: 30,
          onPressed: _edit,
        ),
      ],
    );
  }
}
