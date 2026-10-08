import 'package:flutter/material.dart';

import 'data/store.dart';
import 'models/models.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'widgets/board_header.dart';
import 'widgets/board_view.dart';
import 'widgets/create_dialog.dart';
import 'widgets/detail_drawer.dart';
import 'widgets/list_view.dart';
import 'widgets/nav_pill.dart';
import 'widgets/primitives.dart';

/// L'écran unique de la V1 : fond pointillé, nav, en-tête, tableau, et le
/// bandeau d'erreur d'enregistrement.
class BoardPage extends StatelessWidget {
  const BoardPage({super.key, required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: T.bg,
    body: DottedBackground(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.loading) {
            return const Center(
              child: CircularProgressIndicator(color: T.accent),
            );
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                T.pagePadding,
                20,
                T.pagePadding,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NavPill(
                    store: store,
                    onCreate: () => showCreateRequestDialog(context, store),
                  ),
                  const SizedBox(height: 18),
                  // `saveError` n'arrive qu'à la notification suivante : il
                  // se lit ici, pas au retour d'une mutation.
                  if (store.saveError != null) ...[
                    _SaveErrorBanner(store: store),
                    const SizedBox(height: 18),
                  ],
                  BoardHeader(store: store),
                  const SizedBox(height: 18),
                  if (store.viewMode == ViewMode.board)
                    BoardView(
                      store: store,
                      onOpenRequest: (number) =>
                          showRequestDetail(context, store, number),
                    )
                  else
                    RequestListView(
                      store: store,
                      onOpenRequest: (number) =>
                          showRequestDetail(context, store, number),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Une écriture perdue en silence, c'est du travail perdu : on le dit.
class _SaveErrorBanner extends StatelessWidget {
  const _SaveErrorBanner({required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) => InkOutline(
    radius: T.rChip,
    color: T.typeColor(RequestType.bug),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Expanded(child: Text(store.saveError!, style: TextStyles.body)),
        const SizedBox(width: 12),
        PillButton(
          label: 'Masquer',
          style: PillStyle.ghost,
          height: 34,
          onPressed: store.dismissSaveError,
        ),
      ],
    ),
  );
}
