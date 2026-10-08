import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'primitives.dart';

/// La fenêtre de création. Échap annule (fond translucide de `showGeneralDialog`).
Future<void> showCreateRequestDialog(
  BuildContext context,
  ChantierStore store,
) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Annuler',
  barrierColor: T.backdrop,
  transitionDuration: const Duration(milliseconds: 150),
  pageBuilder: (_, _, _) => _CreateDialog(store: store),
);

class _CreateDialog extends StatefulWidget {
  const _CreateDialog({required this.store});

  final ChantierStore store;

  @override
  State<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends State<_CreateDialog> {
  final _title = TextEditingController();
  RequestType _type = RequestType.feature;

  /// L'intervenant proposé par défaut est l'utilisateur courant (prototype).
  String? _assigneeId;

  @override
  void initState() {
    super.initState();
    _assigneeId = widget.store.currentUserId;
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _valid => _title.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    widget.store.createRequest(
      title: _title.text,
      type: _type,
      assigneeId: _assigneeId,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.5),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: T.dialogWidth,
        // `TextField` et `InkWell` réclament un `Material` ancêtre, que la
        // route de dialogue ne fournit pas.
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
                children: [
                  Text('Nouvelle demande', style: TextStyles.panelTitle),
                  const SizedBox(height: 16),
                  const Text('Titre', style: TextStyles.label),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _title,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                    style: TextStyles.body.copyWith(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Ex. : export en CSV des scans',
                      hintStyle: TextStyles.sub,
                      filled: true,
                      fillColor: T.bg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: T.ink,
                          width: T.borderWidth,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: T.ink,
                          width: T.borderWidth,
                        ),
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
                  const SizedBox(height: 16),
                  const Text('Type', style: TextStyles.label),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final type in RequestType.values)
                        ChoicePill(
                          label: type.label,
                          selected: _type == type,
                          fill: T.typeColor(type),
                          onTap: () => setState(() => _type = type),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Intervenant', style: TextStyles.label),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final person in widget.store.people)
                        ChoicePill(
                          label: person.name,
                          avatar: person,
                          selected: _assigneeId == person.id,
                          fill: T.accentSoft,
                          onTap: () => setState(() => _assigneeId = person.id),
                        ),
                      ChoicePill(
                        label: 'Personne',
                        showAvatar: true,
                        selected: _assigneeId == null,
                        fill: T.accentSoft,
                        onTap: () => setState(() => _assigneeId = null),
                      ),
                    ],
                  ),
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
                      PillButton(
                        label: 'Créer la demande',
                        height: 44,
                        onPressed: _valid ? _submit : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
