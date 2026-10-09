import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'dashed.dart';
import 'primitives.dart';

/// Ce que le menu rend à celui qui l'a ouvert. Choisir un projet est traité
/// sur place ; créer et supprimer ouvrent une fenêtre, donc après la fermeture
/// du menu — depuis un contexte encore monté.
enum _MenuAction { createProject, deleteProject, people, clearAll }

typedef _MenuChoice = ({_MenuAction action, String? projectId});

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

  final ArdoiseStore store;

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
              // `createProject` ne borne pas la longueur du nom : sans
              // `Flexible` + ellipsis, un projet au nom un peu long fait
              // déborder la barre de navigation, en dur.
              Flexible(
                child: Text(
                  '${store.project.name} ▾',
                  style: TextStyles.bold800,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
    switch (choice.action) {
      case _MenuAction.createProject:
        await showCreateProjectDialog(context, store);
      case _MenuAction.deleteProject:
        await _showDeleteProjectDialog(context, store, choice.projectId!);
      case _MenuAction.people:
        await showPeopleDialog(context, store);
      case _MenuAction.clearAll:
        await _showClearAllDialog(context, store);
    }
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.store, required this.anchor});

  final ArdoiseStore store;
  final Offset anchor;

  static const _width = 340.0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Sur un écran plus étroit que le menu, 340 px en dur le font déborder.
    final width = math.min(_width, screenWidth - 16);
    return Stack(
      children: [
        Positioned(
          // Le menu ne doit pas sortir de l'écran quand la pilule est à droite.
          left: math.max(8, math.min(anchor.dx, screenWidth - width - 8)),
          top: anchor.dy,
          child: Material(
            type: MaterialType.transparency,
            child: InkOutline(
              radius: T.rPanel,
              color: T.surface,
              shadow: T.panelShadow,
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: width,
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
                        onDelete: () => Navigator.of(context).pop((
                          action: _MenuAction.deleteProject,
                          projectId: project.id,
                        )),
                      ),
                    const SizedBox(height: 8),
                    const DashedDivider(),
                    const SizedBox(height: 8),
                    PillButton(
                      label: 'Nouveau projet',
                      height: 40,
                      onPressed: () => Navigator.of(context).pop((
                        action: _MenuAction.createProject,
                        projectId: null,
                      )),
                    ),
                    const SizedBox(height: 6),
                    PillButton(
                      label: 'Personnes',
                      style: PillStyle.ghost,
                      height: 40,
                      onPressed: () => Navigator.of(context)
                          .pop((action: _MenuAction.people, projectId: null)),
                    ),
                    const SizedBox(height: 8),
                    const DashedDivider(),
                    const SizedBox(height: 8),
                    // Détruit tout : séparé du reste par un filet, et il
                    // demande confirmation.
                    PillButton(
                      label: 'Tout effacer',
                      style: PillStyle.ghost,
                      height: 40,
                      onPressed: () => Navigator.of(context)
                          .pop((action: _MenuAction.clearAll, projectId: null)),
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
  ArdoiseStore store,
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
  ArdoiseStore store,
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

  final ArdoiseStore store;

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

  final ArdoiseStore store;
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

/// Le panneau des personnes : ajouter, renommer, retirer, et désigner qui
/// vous êtes. Les identifiants ne bougent jamais — renommer est donc le bon
/// geste pour remplacer une personne d'exemple sans détacher ses demandes.
Future<void> showPeopleDialog(BuildContext context, ArdoiseStore store) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fermer',
      barrierColor: T.backdrop,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (_, _, _) =>
          _PeopleDialog(key: const Key('people-dialog'), store: store),
    );

class _PeopleDialog extends StatefulWidget {
  const _PeopleDialog({super.key, required this.store});

  final ArdoiseStore store;

  @override
  State<_PeopleDialog> createState() => _PeopleDialogState();
}

class _PeopleDialogState extends State<_PeopleDialog> {
  final _name = TextEditingController();

  /// Identifiant de la personne en cours de renommage, `#` pour un ajout,
  /// `null` quand on ne saisit rien.
  String? _editing;
  String? _refusal;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _startEdit(String id, String value) => setState(() {
    _editing = id;
    _refusal = null;
    _name.text = value;
    _name.selection = TextSelection.collapsed(offset: value.length);
  });

  void _cancel() => setState(() {
    _editing = null;
    _refusal = null;
    _name.clear();
  });

  void _commit() {
    final id = _editing;
    if (id == null) return;
    final refusal = id == '#'
        ? widget.store.createPerson(name: _name.text)
        : widget.store.renamePerson(id, _name.text);
    setState(() {
      _refusal = refusal;
      if (refusal == null) {
        _editing = null;
        _name.clear();
      }
    });
  }

  void _delete(String id) =>
      setState(() => _refusal = widget.store.deletePerson(id));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => _DialogShell(
      children: [
        Text('Personnes', style: TextStyles.panelTitle),
        const SizedBox(height: 6),
        Text(
          'Renommer garde les demandes : c’est le moyen de remplacer une '
          'personne d’exemple sans rien détacher.',
          style: TextStyles.sub,
        ),
        const SizedBox(height: 16),
        for (final person in widget.store.people)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _editing == person.id
                ? _NameField(
                    controller: _name,
                    onSubmit: _commit,
                    onCancel: _cancel,
                  )
                : _PersonRow(
                    person: person,
                    isMe: person.id == widget.store.currentUserId,
                    onSetMe: () => widget.store.setCurrentUser(person.id),
                    onRename: () => _startEdit(person.id, person.name),
                    onDelete: () => _delete(person.id),
                  ),
          ),
        const SizedBox(height: 6),
        if (_editing == '#')
          _NameField(
            controller: _name,
            onSubmit: _commit,
            onCancel: _cancel,
            hint: 'Son prénom',
          )
        else
          PillButton(
            label: 'Nouvelle personne',
            height: 40,
            onPressed: () => _startEdit('#', ''),
          ),
        if (_refusal != null) _Refusal(_refusal!),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: PillButton(
            label: 'Fermer',
            style: PillStyle.ghost,
            height: 44,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    ),
  );
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.isMe,
    required this.onSetMe,
    required this.onRename,
    required this.onDelete,
  });

  final Person person;
  final bool isMe;
  final VoidCallback onSetMe;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final nom = Row(
      children: [
        PersonAvatar(person: person, size: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            person.name,
            style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final actions = <Widget>[
      if (isMe)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'vous',
            style: TextStyles.meta.copyWith(color: T.accentInk),
          ),
        )
      else
        _MiniButton(label: 'C’est moi', onTap: onSetMe),
      _MiniButton(
        glyph: '✎',
        semanticLabel: 'Renommer ${person.name}',
        onTap: onRename,
      ),
      _MiniButton(
        glyph: '✕',
        semanticLabel: 'Supprimer ${person.name}',
        onTap: onDelete,
      ),
    ];

    return InkOutline(
      radius: T.rChip,
      color: isMe ? T.accentSoft : T.surface,
      borderColor: isMe ? T.ink : T.line,
      padding: const EdgeInsets.all(6),
      // Au large, tout sur une rangée. À l'étroit, le nom garde sa ligne et
      // les actions passent dessous : à 280 px la rangée unique débordait de
      // 81 px. Même motif que les lignes de la vue Liste.
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 340
            ? Row(
                children: [
                  Expanded(child: nom),
                  for (final action in actions) ...[
                    const SizedBox(width: 6),
                    action,
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  nom,
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: actions),
                ],
              ),
      ),
    );
  }
}

/// Un bouton de rangée : soit un libellé, soit un glyphe décoratif doublé
/// d'un nom accessible.
class _MiniButton extends StatelessWidget {
  const _MiniButton({
    this.label,
    this.glyph,
    this.semanticLabel,
    required this.onTap,
  });

  final String? label;
  final String? glyph;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InkOutline(
        radius: 16,
        color: T.bg,
        borderColor: T.line,
        padding: EdgeInsets.symmetric(horizontal: glyph != null ? 9 : 11),
        child: SizedBox(
          height: 32 - 2 * T.borderWidth,
          child: Center(
            widthFactor: 1,
            child: glyph != null
                ? ExcludeSemantics(
                    child: Text(glyph!, style: TextStyles.bold800),
                  )
                : Text(
                    label!,
                    style: TextStyles.meta.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}

/// Le champ de saisie d'un nom, partagé par l'ajout et le renommage.
class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.onSubmit,
    required this.onCancel,
    this.hint,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final String? hint;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          key: const Key('person-name'),
          controller: controller,
          autofocus: true,
          onSubmitted: (_) => onSubmit(),
          style: TextStyles.body.copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint ?? 'Son prénom',
            hintStyle: TextStyles.sub,
            filled: true,
            fillColor: T.bg,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: T.ink, width: T.borderWidth),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: T.ink, width: T.borderWidth),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: T.accent,
                width: T.borderWidth,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 6),
      _MiniButton(glyph: '✓', semanticLabel: 'Valider', onTap: onSubmit),
      const SizedBox(width: 6),
      _MiniButton(glyph: '✕', semanticLabel: 'Annuler', onTap: onCancel),
    ],
  );
}

/// Table rase : confirmation nommant ce qui part.
Future<void> _showClearAllDialog(BuildContext context, ArdoiseStore store) {
  final projets = store.projects.length;
  final demandes = store.projects.fold<int>(
    0,
    (total, p) => total + store.requestCountOf(p.id),
  );
  final personnes = store.people.length;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Annuler',
    barrierColor: T.backdrop,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (dialogContext, _, _) => _DialogShell(
      children: [
        Text('Tout effacer', style: TextStyles.panelTitle),
        const SizedBox(height: 12),
        Text(
          '$projets projet${projets > 1 ? 's' : ''}, '
          '$demandes demande${demandes > 1 ? 's' : ''} et '
          '$personnes personne${personnes > 1 ? 's' : ''} seront supprimés. '
          'Il restera un projet et une personne vides, à renommer. '
          'C’est irréversible.',
          style: TextStyles.description,
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PillButton(
              label: 'Annuler',
              style: PillStyle.ghost,
              height: 44,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            const SizedBox(width: 8),
            PillButton(
              label: 'Tout effacer',
              height: 44,
              onPressed: () {
                store.clearAll();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        ),
      ],
    ),
  );
}
