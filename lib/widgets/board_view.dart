import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'avatar.dart';
import 'dashed.dart';
import 'primitives.dart';
import 'request_card.dart';

/// Les colonnes du tableau et leur défilement horizontal.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.store,
    required this.onOpenRequest,
  });

  final ChantierStore store;
  final void Function(int number) onOpenRequest;

  @override
  Widget build(BuildContext context) {
    // `store.columns` recalcule tout à chaque accès : une seule lecture.
    final columns = store.columns;
    if (columns.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Aucune colonne : toutes les personnes sont masquées.',
            style: TextStyles.sub,
          ),
        ),
      );
    }

    Widget columnAt(int i) =>
        _Column(store: store, column: columns[i], onOpenRequest: onOpenRequest);

    // `minmax(250px, 1fr)` du prototype : les colonnes se partagent la largeur
    // quand il y en a assez, et tombent à 250 px avec défilement sinon.
    Row row({required bool share}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: T.columnGap),
          if (share)
            Expanded(child: columnAt(i))
          else
            SizedBox(width: T.columnMinWidth, child: columnAt(i)),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final needed =
            columns.length * T.columnMinWidth +
            (columns.length - 1) * T.columnGap;
        if (constraints.maxWidth >= needed) return row(share: true);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 8),
          child: row(share: false),
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.store,
    required this.column,
    required this.onOpenRequest,
  });

  final ChantierStore store;
  final BoardColumn column;
  final void Function(int number) onOpenRequest;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 200),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: T.column,
      borderRadius: BorderRadius.circular(T.rColumn),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            children: [
              if (column.dotColor != null)
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: column.dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: T.ink, width: T.borderWidth),
                  ),
                )
              else
                PersonAvatar(person: column.person, size: 38),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  column.title,
                  style: TextStyles.columnTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (column.countAtEnd)
                const Spacer()
              else
                const SizedBox(width: 8),
              CountBadge(column.requests.length),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (column.requests.isEmpty)
          DashedBorder(
            radius: 16,
            color: T.line,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: Center(
                child: Text(
                  'Rien ce mois-ci',
                  style: TextStyles.sub,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          for (final request in column.requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RequestCard(
                store: store,
                request: request,
                onOpen: () => onOpenRequest(request.number),
              ),
            ),
      ],
    ),
  );
}
