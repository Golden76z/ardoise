import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../theme/tokens.dart';
import 'primitives.dart';

/// Le choix du thème de couleurs : une pastille ronde dans la barre de
/// navigation, qui ouvre la liste des palettes.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  static const _size = 42.0;

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return PopupMenuButton<ArdoisePalette>(
      tooltip: 'Thème de couleurs',
      position: PopupMenuPosition.under,
      color: T.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(T.rChip),
        side: BorderSide(color: T.softOutline, width: T.softOutlineWidth),
      ),
      onSelected: controller.select,
      itemBuilder: (context) => [
        for (final palette in ArdoisePalette.all)
          PopupMenuItem(
            value: palette,
            // Pas d'`Expanded` : un menu se dimensionne par largeur
            // intrinsèque, et des noms courts n'ont rien à abréger.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Swatch(palette: palette),
                const SizedBox(width: 10),
                Text(
                  palette.name,
                  style: TextStyles.body.copyWith(
                    fontWeight: palette.id == controller.palette.id
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
                if (palette.id == controller.palette.id) ...[
                  const SizedBox(width: 10),
                  Text('✓', style: TextStyles.bold800),
                ],
              ],
            ),
          ),
      ],
      child: Semantics(
        label: 'Thème : ${controller.palette.name}',
        child: InkOutline(
          radius: _size / 2,
          color: T.surface,
          borderColor: T.line,
          child: SizedBox(
            width: _size - 2 * T.borderWidth,
            height: _size - 2 * T.borderWidth,
            child: Center(child: _Swatch(palette: controller.palette)),
          ),
        ),
      ),
    );
  }
}

/// Deux demi-disques : l'accent et le fond de la palette.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.palette});

  final ArdoisePalette palette;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: palette.ink, width: T.borderWidth),
      gradient: LinearGradient(
        colors: [palette.accent, palette.accent, palette.bg, palette.bg],
        stops: const [0, 0.5, 0.5, 1],
      ),
    ),
  );
}
