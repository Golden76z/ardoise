import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'primitives.dart';

/// Saisie d'une échéance : « jj/mm/aaaa » au clavier, plus des raccourcis.
/// Pas de `showDatePicker` : sans `flutter_localizations` (nouvelle
/// dépendance), il s'afficherait en anglais.
///
/// La valeur part dans `onChanged` à la validation (Entrée, perte du focus,
/// raccourci) ; vide = aucune échéance ; illisible = message, rien n'est
/// changé.
class DueDateInput extends StatefulWidget {
  const DueDateInput({
    super.key,
    required this.value,
    required this.today,
    required this.onChanged,
  });

  final DateTime? value;
  final DateTime today;
  final ValueChanged<DateTime?> onChanged;

  @override
  State<DueDateInput> createState() => _DueDateInputState();
}

class _DueDateInputState extends State<DueDateInput> {
  late final _text = TextEditingController(text: _format(widget.value));
  final _focus = FocusNode();
  String? _error;

  static String _format(DateTime? date) =>
      date == null ? '' : formatNumericDate(date);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(DueDateInput old) {
    super.didUpdateWidget(old);
    // Modifiée ailleurs (Obsidian, raccourci) : le champ suit, sauf pendant
    // la frappe.
    if (old.value != widget.value && !_focus.hasFocus) {
      _text.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final raw = _text.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = null);
      if (widget.value != null) widget.onChanged(null);
      return;
    }
    final date = parseFrenchDate(raw);
    if (date == null) {
      setState(() => _error = 'Date illisible : écris-la jj/mm/aaaa.');
      return;
    }
    setState(() => _error = null);
    _text.text = formatNumericDate(date);
    if (date != widget.value) widget.onChanged(date);
  }

  void _set(DateTime? date) {
    _text.text = _format(date);
    setState(() => _error = null);
    widget.onChanged(date);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 150,
              child: TextField(
                controller: _text,
                focusNode: _focus,
                keyboardType: TextInputType.datetime,
                onSubmitted: (_) => _commit(),
                style: TextStyles.body,
                decoration: inkInputDecoration(hint: 'jj/mm/aaaa'),
              ),
            ),
            PillButton(
              label: 'Aujourd’hui',
              style: PillStyle.ghost,
              height: 34,
              onPressed: () => _set(today),
            ),
            PillButton(
              label: '+ 1 semaine',
              style: PillStyle.ghost,
              height: 34,
              onPressed: () => _set(today.add(const Duration(days: 7))),
            ),
            if (widget.value != null)
              PillButton(
                label: 'Retirer',
                style: PillStyle.ghost,
                height: 34,
                onPressed: () => _set(null),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(_error!, style: TextStyles.meta),
          ),
        ],
      ],
    );
  }
}
