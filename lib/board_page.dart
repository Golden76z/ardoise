import 'package:flutter/material.dart';

import 'data/store.dart';
import 'models/models.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
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

  final ArdoiseStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: ThemeController.instance,
    // Changer de palette remonte toute la page : les couleurs de `T` sont
    // lues au `build`, et un widget `const` ne se reconstruit pas tout seul.
    builder: (context, _) => KeyedSubtree(
      key: ValueKey(ThemeController.instance.palette.id),
      child: _page(),
    ),
  );

  Widget _page() => Scaffold(
    backgroundColor: T.bg,
    body: DottedBackground(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.loading) {
            return Center(
              child: CircularProgressIndicator(color: T.accent),
            );
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isPhone(context) ? T.pagePaddingPhone : T.pagePadding,
                20,
                isPhone(context) ? T.pagePaddingPhone : T.pagePadding,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
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

/// La barre de navigation, centrée sur la page. Au large, le titre du projet
/// occupe le coin haut gauche, à sa hauteur : deux `Expanded` de part et
/// d'autre gardent la barre au centre exact, et le titre s'abrège plutôt que
/// de la chevaucher.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.store, required this.onCreate});

  final ArdoiseStore store;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final nav = NavPill(store: store, onCreate: onCreate);
    if (!titleBesideNav(context)) return nav;
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: ProjectTitle(store: store),
          ),
        ),
        const SizedBox(width: 16),
        nav,
        const SizedBox(width: 16),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}

/// Une écriture perdue en silence, c'est du travail perdu : on le dit.
class _SaveErrorBanner extends StatelessWidget {
  const _SaveErrorBanner({required this.store});

  final ArdoiseStore store;

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
