import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'dashed.dart';
import 'primitives.dart';

/// Ce que le menu rend à celui qui l'a ouvert. Choisir un projet est traité
/// sur place ; créer et supprimer ouvrent une fenêtre, donc après la fermeture
/// du menu — depuis un contexte encore monté.
typedef _MenuChoice = ({bool create, String? deleteId});

/// Force la clé en majuscules pendant la frappe : `ech` et `ECH` sont la
/// même clé, autant que ça se voie tout de suite.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue now,
  ) => TextEditingValue(text: now.text.toUpperCase(), selection: now.selection);
}

/// Le sélecteur de projet de la pilule de navigation : un bouton qui déroule
/// la liste des projets juste sous lui.
class ProjectMenu extends StatelessWidget {
  const ProjectMenu({super.key, required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Projet : ${store.project.name}',
    child: InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(T.rNavItem),
      child: InkOutline(
        radius: T.rNavItem,
        color: store.project.color,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: 42 - 2 * T.borderWidth,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${store.project.name} ▾', style: TextStyles.bold800),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _open(BuildContext context) async {
    // Le menu se pose sous la pilule : il lui faut sa position à l'écran.
    final box = context.findRenderObject()! as RenderBox;
    final anchor = box.localToGlobal(Offset(0, box.size.height + 6));

    final choice = await showGeneralDialog<_MenuChoice>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer le sélecteur de projet',
      barrierColor: T.backdrop,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, _, _) => _Dropdown(store: store, anchor: anchor),
    );
    if (choice == null || !context.mounted) return;
    if (choice.create) {
      await showCreateProjectDialog(context, store);
    } else if (choice.deleteId != null) {
      await _showDeleteProjectDialog(context, store, choice.deleteId!);
    }
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.store, required this.anchor});

  final ChantierStore store;
  final Offset anchor;

  static const _width = 340.0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Stack(
      children: [
        Positioned(
          // Le menu ne doit pas sortir de l'écran quand la pilule est à droite.
          left: math.max(8, math.min(anchor.dx, screenWidth - _width - 8)),
          top: anchor.dy,
          child: Material(
            type: MaterialType.transparency,
            child: InkOutline(
              radius: T.rPanel,
              color: T.surface,
              shadow: T.panelShadow,
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: _width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final project in store.projects)
                      _ProjectRow(
                        project: project,
                        count: store.requestCountOf(project.id),
                        selected: project.id == store.currentProjectId,
                        onSelect: () {
                          store.setCurrentProject(project.id);
                          Navigator.of(context).pop();
                        },
                        onDelete: () =>
                            Navigator.of(context)
                                .pop((create: false, deleteId: project.id)),
                      ),
                    const SizedBox(height: 8),
                    const DashedDivider(),
                    const SizedBox(height: 8),
                    PillButton(
                      label: 'Nouveau projet',
                      height: 40,
                      onPressed: () =>
                          Navigator.of(context)
                              .pop((create: true, deleteId: null)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.count,
    required this.selected,
    required this.onSelect,
    required this.onDelete,
  });

  final Project project;
  final int count;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(T.rChip),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
        decoration: BoxDecoration(
          color: selected ? T.accentSoft : null,
          borderRadius: BorderRadius.circular(T.rChip),
        ),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: project.color,
                shape: BoxShape.circle,
                border: Border.all(color: T.ink, width: T.borderWidth),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                project.name,
                style: TextStyles.bold800,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(project.key, style: TextStyles.meta),
            const SizedBox(width: 8),
            CountBadge(count),
            _DeleteButton(
              label: 'Supprimer le projet ${project.name}',
              onTap: onDelete,
            ),
          ],
        ),
      ),
    ),
  );
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 32,
        height: 32,
        // La croix est décorative : le libellé est porté par `Semantics`.
        child: ExcludeSemantics(
          child: Center(
            child: Text(
              '×',
              style: TextStyles.bold800.copyWith(fontSize: 20, color: T.accent),
            ),
          ),
        ),
      ),
    ),
  );
}

/// La fenêtre de création de projet. Même facture que `create_dialog.dart` :
/// Échap annule, le fond translucide ferme.
Future<void> showCreateProjectDialog(
  BuildContext context,
  ChantierStore store,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Annuler',
  barrierColor: T.backdrop,
  transitionDuration: const Duration(milliseconds: 150),
  pageBuilder: (_, _, _) => _CreateProjectDialog(store: store),
);

Future<void> _showDeleteProjectDialog(
  BuildContext context,
  ChantierStore store,
  String id,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Annuler',
  barrierColor: T.backdrop,
  transitionDuration: const Duration(milliseconds: 150),
  pageBuilder: (_, _, _) => _DeleteProjectDialog(
    store: store,
    project: store.projects.firstWhere((p) => p.id == id),
    count: store.requestCountOf(id),
  ),
);

/// La décoration des champs, reprise du champ « Titre » de `create_dialog.dart`.
InputDecoration _fieldDecoration(String hint) {
  const border = BorderSide(color: T.ink, width: T.borderWidth);
  final radius = BorderRadius.circular(16);
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyles.sub,
    filled: true,
    fillColor: T.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    border: OutlineInputBorder(borderRadius: radius, borderSide: border),
    enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: border),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: T.accent, width: T.borderWidth),
    ),
  );
}

/// L'enveloppe commune aux deux fenêtres de ce fichier : la route de dialogue
/// ne fournit pas le `Material` que `TextField` et `InkWell` réclament.
class _DialogShell extends StatelessWidget {
  const _DialogShell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.5),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: T.dialogWidth,
        child: Material(
          type: MaterialType.transparency,
          child: InkOutline(
            radius: T.rPanel,
            color: T.surface,
            shadow: T.panelShadow,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Le motif du refus rendu par le store, sous les champs.
class _Refusal extends StatelessWidget {
  const _Refusal(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Text(
      message,
      style: TextStyles.body.copyWith(
        color: T.accentInk,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog({required this.store});

  final ChantierStore store;

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _name = TextEditingController();
  final _key = TextEditingController();
  Color _color = T.projectPalette.first;
  String? _refusal;

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    super.dispose();
  }

  /// Le bouton reste actif : c'est le store qui arbitre, et son motif de refus
  /// en dit plus long qu'un bouton grisé.
  void _submit() {
    final refusal = widget.store.createProject(
      name: _name.text,
      key: _key.text,
      color: _color,
    );
    if (refusal == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _refusal = refusal);
  }

  @override
  Widget build(BuildContext context) => _DialogShell(
    children: [
      Text('Nouveau projet', style: TextStyles.panelTitle),
      const SizedBox(height: 16),
      const Text('Nom', style: TextStyles.label),
      const SizedBox(height: 8),
      TextField(
        key: const Key('project-name'),
        controller: _name,
        autofocus: true,
        style: TextStyles.body.copyWith(fontSize: 16),
        decoration: _fieldDecoration('Ex. : Atelier'),
      ),
      const SizedBox(height: 16),
      const Text('Clé — préfixe des références', style: TextStyles.label),
      const SizedBox(height: 8),
      TextField(
        key: const Key('project-key'),
        controller: _key,
        onSubmitted: (_) => _submit(),
        inputFormatters: [
          LengthLimitingTextInputFormatter(5),
          const UpperCaseTextFormatter(),
        ],
        style: TextStyles.body.copyWith(fontSize: 16),
        decoration: _fieldDecoration('Ex. : ATL — 5 caractères au plus'),
      ),
      const SizedBox(height: 16),
      const Text('Couleur', style: TextStyles.label),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (index, color) in T.projectPalette.indexed)
            Semantics(
              button: true,
              selected: _color == color,
              label: 'Couleur ${index + 1}',
              child: InkWell(
                onTap: () => setState(() => _color = color),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _color == color ? T.ink : T.line,
                      width: _color == color ? 3 : T.borderWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      if (_refusal != null) _Refusal(_refusal!),
      const SizedBox(height: 22),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PillButton(
            label: 'Annuler',
            style: PillStyle.ghost,
            height: 44,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          PillButton(label: 'Créer le projet', height: 44, onPressed: _submit),
        ],
      ),
    ],
  );
}

class _DeleteProjectDialog extends StatefulWidget {
  const _DeleteProjectDialog({
    required this.store,
    required this.project,
    required this.count,
  });

  final ChantierStore store;
  final Project project;
  final int count;

  @override
  State<_DeleteProjectDialog> createState() => _DeleteProjectDialogState();
}

class _DeleteProjectDialogState extends State<_DeleteProjectDialog> {
  String? _refusal;

  void _confirm() {
    final refusal = widget.store.deleteProject(widget.project.id);
    if (refusal == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _refusal = refusal);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count;
    return _DialogShell(
      children: [
        Text('Supprimer ce projet ?', style: TextStyles.panelTitle),
        const SizedBox(height: 14),
        Text(
          'Le projet « ${widget.project.name} » et ses $count '
          'demande${count > 1 ? 's' : ''} seront supprimés. C’est définitif.',
          style: TextStyles.description,
        ),
        if (_refusal != null) _Refusal(_refusal!),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PillButton(
              label: 'Annuler',
              style: PillStyle.ghost,
              height: 44,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            PillButton(label: 'Supprimer', height: 44, onPressed: _confirm),
          ],
        ),
      ],
    );
  }
}
