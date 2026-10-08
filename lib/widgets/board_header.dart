import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'dashed.dart';
import 'primitives.dart';

/// Titre, sous-titre, segment « Colonnes », puces de type, et la barre des
/// personnes en mode Intervenant / Demandeur.
class BoardHeader extends StatelessWidget {
  const BoardHeader({super.key, required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(store.project.name, style: TextStyles.pageTitle),
              const SizedBox(height: 6),
              Text(store.subtitle, style: TextStyles.sub),
            ],
          ),
          _GroupingSegment(store: store),
          _TypeChips(store: store),
        ],
      ),
      if (store.grouping != BoardGrouping.status) ...[
        const SizedBox(height: 18),
        _PeopleBar(store: store),
      ],
    ],
  );
}

class _GroupingSegment extends StatelessWidget {
  const _GroupingSegment({required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) => InkOutline(
    radius: 22,
    color: T.surface,
    padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Colonnes', style: TextStyles.meta),
        const SizedBox(width: 8),
        for (final grouping in BoardGrouping.values)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _SegButton(
              label: grouping.label,
              selected: store.grouping == grouping,
              onTap: () => store.setGrouping(grouping),
            ),
          ),
      ],
    ),
  );
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? T.accent : null,
          borderRadius: BorderRadius.circular(17),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyles.bold800.copyWith(
            color: selected ? T.surface : T.ink,
          ),
        ),
      ),
    ),
  );
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final type in RequestType.values)
        _TypeChip(
          label: type.shortLabel,
          // Le compteur ignore volontairement le filtre de type.
          count: store.countOfType(type),
          active: store.isTypeActive(type),
          color: T.typeColor(type),
          onTap: () => store.toggleType(type),
        ),
    ],
  );
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.count,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 7),
            Text('$count', style: TextStyles.bold800),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: active,
      label: 'Filtrer : $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.rChip),
        child: active
            ? InkOutline(radius: T.rChip, color: color, child: body)
            : DashedBorder(
                radius: T.rChip,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: T.surface,
                    borderRadius: BorderRadius.circular(T.rChip),
                  ),
                  child: body,
                ),
              ),
      ),
    );
  }
}

class _PeopleBar extends StatelessWidget {
  const _PeopleBar({required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) => DashedBorder(
    radius: T.rChip,
    color: T.line,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            store.grouping == BoardGrouping.assignee
                ? 'Intervenants affichés'
                : 'Demandeurs affichés',
            style: TextStyles.sub.copyWith(fontWeight: FontWeight.w600),
          ),
          for (final person in store.people)
            _PersonToggle(
              person: person,
              shown: store.isPersonShown(person.id),
              onTap: () => store.togglePerson(person.id),
            ),
        ],
      ),
    ),
  );
}

class _PersonToggle extends StatelessWidget {
  const _PersonToggle({
    required this.person,
    required this.shown,
    required this.onTap,
  });

  final Person person;
  final bool shown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 12, 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PersonAvatar(person: person, size: 28),
          const SizedBox(width: 7),
          Text(
            person.name,
            style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: shown,
      label: 'Afficher ${person.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: SizedBox(
          height: 38,
          child: shown
              ? InkOutline(radius: 19, color: T.surface, child: body)
              : Opacity(
                  opacity: 0.6,
                  child: DashedBorder(radius: 19, child: body),
                ),
        ),
      ),
    );
  }
}
