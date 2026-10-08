import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'primitives.dart';
import 'project_menu.dart';

/// La barre de navigation en pilule flottante : logo, projet, onglets,
/// sélecteur de mois, bouton de création.
class NavPill extends StatelessWidget {
  const NavPill({super.key, required this.store, required this.onCreate});

  final ArdoiseStore store;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final phone = isPhone(context);
    final logo = Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(color: T.accent, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        'A',
        style: TextStyles.bold800.copyWith(color: T.bg, fontSize: 20),
      ),
    );
    final tabs = [
      for (final mode in ViewMode.values)
        _NavChip(
          label: mode.label,
          active: store.viewMode == mode,
          onTap: () => store.setViewMode(mode),
        ),
    ];
    // Le sélecteur de mois n'a aucun sens sur une vue qui les ignore.
    final month = store.viewMode == ViewMode.board
        ? _MonthPicker(store: store)
        : null;

    return Center(
      child: InkOutline(
        radius: T.rNav,
        color: T.surface,
        shadow: T.navShadow,
        padding: const EdgeInsets.all(7),
        // Sur téléphone, deux rangées décidées plutôt qu'un `Wrap` subi : à
        // 400 px de large, le repli automatique sortait « Liste » seule à
        // droite et « Votes » orpheline au-dessus du bouton.
        child: phone
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      logo,
                      const SizedBox(width: 6),
                      Flexible(child: ProjectMenu(store: store)),
                      const SizedBox(width: 6),
                      // Icône seule : le libellé coûtait une rangée entière.
                      PillButton(
                        label: '+',
                        onPressed: onCreate,
                        semanticLabel: 'Nouvelle demande',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Un `Wrap` ici, mais sur un contenu homogène : à 320 px le
                  // sélecteur de mois descend sous les onglets, et c'est
                  // toujours lisible. Le `Wrap` d'origine mélangeait logo,
                  // projet, onglets et bouton, d'où le résultat bancal.
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...tabs,
                      // « Votes » est inerte (handoff §4) : au téléphone elle
                      // coûterait de la largeur pour rien.
                      ?month,
                    ],
                  ),
                ],
              )
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  logo,
                  ProjectMenu(store: store),
                  ...tabs,
                  // La vue Votes reste inerte : hors périmètre (handoff §4).
                  const _NavChip(label: 'Votes', active: false),
                  ?month,
                  PillButton(label: '+ Demande', onPressed: onCreate),
                ],
              ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.label, required this.active, this.onTap});

  final String label;
  final bool active;

  /// `null` pour un onglet encore inerte : il n'est alors pas focusable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      height: 42,
      padding: EdgeInsets.symmetric(horizontal: active ? 14 : 12),
      decoration: BoxDecoration(
        color: active ? T.accentSoft : null,
        borderRadius: BorderRadius.circular(T.rNavItem),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: active
                ? TextStyles.bold800.copyWith(color: T.accentInk)
                : TextStyles.body.copyWith(color: T.muted),
          ),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      selected: active,
      child: onTap == null
          ? body
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(T.rNavItem),
              child: body,
            ),
    );
  }
}

/// Navigation de mois libre dans les deux sens, contrairement au prototype qui
/// bornait à trois mois : une demande peut naître n'importe quel mois.
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.store});

  final ArdoiseStore store;

  @override
  Widget build(BuildContext context) {
    // « Octobre 2026 » sur 128 px faisait déborder la rangée de 83 px à
    // 412 px de large : au téléphone, « oct. 2026 » suffit.
    final phone = isPhone(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: T.bg,
        borderRadius: BorderRadius.circular(T.rNavItem),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Arrow(
            label: 'Mois précédent',
            glyph: '‹',
            onTap: () => store.shiftMonth(-1),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: phone ? 86 : 128,
            // Hauteur figée à 42 : sans `maxLines`, « janv. 2026 » à grande
            // échelle de police se replie sur deux lignes et la seconde est
            // coupée en silence au lieu d'être abrégée.
            child: Text(
              phone
                  ? formatMonthLabelShort(store.visibleMonth)
                  : formatMonthLabel(store.visibleMonth),
              textAlign: TextAlign.center,
              style: TextStyles.bold800,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          _Arrow(
            label: 'Mois suivant',
            glyph: '›',
            onTap: () => store.shiftMonth(1),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.label, required this.glyph, required this.onTap});

  final String label;
  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: T.surface,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        // Le chevron est décoratif : sans cela il se colle au libellé lu
        // par les lecteurs d'écran (« Mois précédent ‹ »).
        child: ExcludeSemantics(
          child: Text(
            glyph,
            style: TextStyles.bold800.copyWith(color: T.accent),
          ),
        ),
      ),
    ),
  );
}
