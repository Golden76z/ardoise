import 'package:flutter/material.dart';

import '../data/store.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'primitives.dart';

/// La barre de navigation en pilule flottante : logo, projet, onglets,
/// sélecteur de mois, bouton de création.
class NavPill extends StatelessWidget {
  const NavPill({super.key, required this.store, required this.onCreate});

  final ChantierStore store;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: InkOutline(
      radius: T.rNav,
      color: T.surface,
      shadow: T.navShadow,
      padding: const EdgeInsets.all(7),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: T.accent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              'C',
              style: TextStyles.bold800.copyWith(color: T.bg, fontSize: 20),
            ),
          ),
          InkOutline(
            radius: T.rNavItem,
            color: T.project,
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
          const _NavChip(label: 'Tableau', active: true),
          // Vues Liste et Votes : hors périmètre V1 (handoff §4).
          const _NavChip(label: 'Liste', active: false),
          const _NavChip(label: 'Votes', active: false),
          _MonthPicker(store: store),
          PillButton(label: '+ Demande', onPressed: onCreate),
        ],
      ),
    ),
  );
}

class _NavChip extends StatelessWidget {
  const _NavChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: active,
    // Non focusable : l'onglet n'est pas encore une vue (handoff §4).
    child: Container(
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
    ),
  );
}

/// Navigation de mois libre dans les deux sens, contrairement au prototype qui
/// bornait à trois mois : une demande peut naître n'importe quel mois.
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) => Container(
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
          width: 128,
          child: Text(
            formatMonthLabel(store.visibleMonth),
            textAlign: TextAlign.center,
            style: TextStyles.bold800,
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
