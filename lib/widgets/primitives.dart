import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'avatar.dart';

/// Le fond crème à petits points — `radial-gradient(... 1.2px) 20px 20px`.
class DottedBackground extends StatelessWidget {
  const DottedBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: T.bg,
    child: CustomPaint(painter: const _DotPainter(), child: child),
  );
}

class _DotPainter extends CustomPainter {
  const _DotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = T.bgDot;
    for (var y = 0.0; y < size.height; y += T.dotSpacing) {
      for (var x = 0.0; x < size.width; x += T.dotSpacing) {
        canvas.drawCircle(Offset(x, y), T.dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) => false;
}

/// « Contour encre + coin arrondi » : la brique de tout le design.
class InkOutline extends StatelessWidget {
  const InkOutline({
    super.key,
    required this.child,
    required this.radius,
    this.color,
    this.padding,
    this.shadow,
    this.borderColor = T.ink,
    this.borderWidth = T.borderWidth,
  });

  final Widget child;
  final double radius;
  final Color? color;
  final EdgeInsets? padding;
  final List<BoxShadow>? shadow;
  final Color borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: shadow,
    ),
    child: child,
  );
}

enum PillStyle { primary, ghost }

/// Bouton en pilule. `onPressed: null` le désactive (opacité 45 %, prototype).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PillStyle.primary,
    this.height = 42,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final PillStyle style;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final primary = style == PillStyle.primary;
    final pill = InkOutline(
      radius: height / 2,
      color: primary ? T.accent : T.surface,
      borderColor: primary ? T.ink : T.line,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      // Pas d'`Align` ni de `Center` : sous les contraintes lâches d'un `Wrap`
      // ils s'étirent à toute la largeur disponible.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyles.bold800.copyWith(
              color: primary ? T.surface : T.ink,
            ),
          ),
        ],
      ),
    );

    // `InkWell` sur `Material` donne focus clavier, survol et retour tactile
    // sans plomberie — la contrainte d'accessibilité l'exige.
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(height / 2),
            focusColor: T.accentSoft,
            child: SizedBox(height: height, child: pill),
          ),
        ),
      ),
    );
  }
}

/// Un choix dans un panneau : statut, intervenant, type. Avec avatar quand
/// c'est une personne. Partagé par le tiroir de détail et la fenêtre de
/// création — les deux affichent exactement la même pastille.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.fill,
    required this.onTap,
    this.avatar,
    this.showAvatar = false,
  });

  final String label;
  final bool selected;

  /// Fond quand le choix est retenu.
  final Color fill;
  final VoidCallback onTap;

  /// La personne à montrer ; `null` avec `showAvatar` = « Personne ».
  final Person? avatar;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final withAvatar = avatar != null || showAvatar;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.rChip),
        child: SizedBox(
          height: withAvatar ? 38 : 36,
          child: InkOutline(
            radius: T.rChip,
            color: selected ? fill : T.surface,
            borderColor: selected ? T.ink : T.line,
            padding: EdgeInsets.only(left: withAvatar ? 4 : 13, right: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (withAvatar) ...[
                  PersonAvatar(person: avatar, size: 28),
                  const SizedBox(width: 7),
                ],
                Text(
                  label,
                  style: withAvatar
                      ? TextStyles.body.copyWith(fontWeight: FontWeight.w600)
                      : TextStyles.bold800,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La pastille de statut d'une demande. Partagée par la carte du tableau et
/// la ligne de la vue Liste.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) => InkOutline(
    radius: T.rSmallChip + 1,
    color: T.statusColor(status),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: SizedBox(
      height: 26 - 2 * T.borderWidth,
      // Sans `widthFactor`, `Center` s'étire à toute la largeur sous les
      // contraintes lâches d'un `Wrap`.
      child: Center(
        widthFactor: 1,
        child: Text(
          status.label,
          style: TextStyles.bold800.copyWith(fontSize: T.fsTiny),
        ),
      ),
    ),
  );
}

/// Le bouton de vote `▲ n`. Un seul exemplaire : c'est le seul endroit d'où
/// part `toggleVote`, et il est partagé par la carte et la ligne de liste.
class VoteButton extends StatelessWidget {
  const VoteButton({
    super.key,
    required this.onToggle,
    required this.votes,
    required this.voted,
    required this.title,
  });

  final VoidCallback onToggle;
  final int votes;
  final bool voted;

  /// Sert au libellé d'accessibilité : « Voter pour `titre` ».
  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: voted,
    label: voted ? 'Retirer mon vote sur $title' : 'Voter pour $title',
    child: InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(T.rSmallChip),
      child: InkOutline(
        radius: T.rSmallChip,
        color: voted ? T.accentSoft : T.surface,
        borderColor: voted ? T.ink : T.line,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: SizedBox(
          height: 28 - 2 * T.borderWidth,
          child: Center(
            widthFactor: 1,
            child: Text(
              '▲ $votes',
              style: TextStyles.bold800.copyWith(color: T.accentInk),
            ),
          ),
        ),
      ),
    ),
  );
}

/// La pastille de comptage des colonnes et des puces.
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 26),
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    decoration: BoxDecoration(
      color: T.accentSoft,
      borderRadius: BorderRadius.circular(13),
    ),
    alignment: Alignment.center,
    child: Text(
      '$count',
      style: TextStyles.bold800.copyWith(
        fontSize: T.fsMeta,
        color: T.accentInk,
      ),
    ),
  );
}
