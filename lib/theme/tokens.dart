import 'package:flutter/painting.dart';

import '../models/models.dart';

/// Tokens de `docs/design-tokens.json`. Source unique : aucune couleur
/// littérale ailleurs dans `lib/`.
/// Une palette : toutes les couleurs d'interface. Les couleurs des personnes
/// et des projets n'en font pas partie — elles sont enregistrées avec les
/// données (vault compris) et ne doivent pas changer avec le thème.
class ArdoisePalette {
  const ArdoisePalette({
    required this.id,
    required this.name,
    required this.bg,
    required this.bgDot,
    required this.surface,
    required this.column,
    required this.ink,
    required this.muted,
    required this.line,
    required this.lineStrong,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.shadowOffset,
    required this.project,
    required this.unassigned,
    required this.description,
    required this.bug,
    required this.feature,
    required this.idea,
    required this.todo,
    required this.doing,
    required this.review,
    required this.done,
  });

  /// Enregistré dans les préférences : ne jamais le renommer.
  final String id;

  /// Libellé dans le sélecteur de thème.
  final String name;

  final Color bg;
  final Color bgDot;
  final Color surface;
  final Color column;
  final Color ink;
  final Color muted;
  final Color line;
  final Color lineStrong;
  final Color accent;
  final Color accentSoft;
  final Color accentInk;
  final Color shadowOffset;
  final Color project;
  final Color unassigned;
  final Color description;
  final Color bug;
  final Color feature;
  final Color idea;
  final Color todo;
  final Color doing;
  final Color review;
  final Color done;

  /// Celle de `docs/design-tokens.json` : la palette d'origine.
  static const argile = ArdoisePalette(
    id: 'argile',
    name: 'Argile',
    bg: Color(0xFFFFF4EC),
    bgDot: Color(0xFFF1DCCB),
    surface: Color(0xFFFFFFFF),
    column: Color(0xA6FFFFFF), // blanc à 65 %
    ink: Color(0xFF4A2E22),
    muted: Color(0xFF8A5F48),
    line: Color(0xFFE2C3AE),
    lineStrong: Color(0xFFC9A58E),
    accent: Color(0xFFB4532A),
    accentSoft: Color(0xFFFBE3D4),
    accentInk: Color(0xFF9A4320),
    shadowOffset: Color(0xFFE39A74),
    project: Color(0xFFDDF3EF),
    unassigned: Color(0xFFEFE3D8),
    description: Color(0xFF6E4A38), // `.desc` du prototype
    bug: Color(0xFFFDE1DC),
    feature: Color(0xFFFDE7D6),
    idea: Color(0xFFFCF1CC),
    todo: Color(0xFFF3E6DB),
    doing: Color(0xFFFCEBC4),
    review: Color(0xFFF9DCCB),
    done: Color(0xFFDDEFD3),
  );

  static const ardoise = ArdoisePalette(
    id: 'ardoise',
    name: 'Ardoise',
    bg: Color(0xFFEEF2F6),
    bgDot: Color(0xFFD5DEE8),
    surface: Color(0xFFFFFFFF),
    column: Color(0xA6FFFFFF),
    ink: Color(0xFF1F2A37),
    muted: Color(0xFF5B6B7D),
    line: Color(0xFFC7D2DE),
    lineStrong: Color(0xFF9AAABB),
    accent: Color(0xFF3B6EA8),
    accentSoft: Color(0xFFDCE8F5),
    accentInk: Color(0xFF2C5585),
    shadowOffset: Color(0xFF8FB0D3),
    project: Color(0xFFDCE8F5),
    unassigned: Color(0xFFE3E9EF),
    description: Color(0xFF3A4757),
    bug: Color(0xFFFBE0E0),
    feature: Color(0xFFDCE8F5),
    idea: Color(0xFFFBF0C9),
    todo: Color(0xFFE6ECF2),
    doing: Color(0xFFFBEFC9),
    review: Color(0xFFE9E1F5),
    done: Color(0xFFDCEFD9),
  );

  static const menthe = ArdoisePalette(
    id: 'menthe',
    name: 'Menthe',
    bg: Color(0xFFEEF6F1),
    bgDot: Color(0xFFD3E6DA),
    surface: Color(0xFFFFFFFF),
    column: Color(0xA6FFFFFF),
    ink: Color(0xFF1E3328),
    muted: Color(0xFF557563),
    line: Color(0xFFC3DACB),
    lineStrong: Color(0xFF93B7A0),
    accent: Color(0xFF2F7D5B),
    accentSoft: Color(0xFFD7EEE2),
    accentInk: Color(0xFF23624A),
    shadowOffset: Color(0xFF8CC2A6),
    project: Color(0xFFD7EEE2),
    unassigned: Color(0xFFE2EBE5),
    description: Color(0xFF3B5747),
    bug: Color(0xFFFBE1DC),
    feature: Color(0xFFD7EEE2),
    idea: Color(0xFFFAF1CB),
    todo: Color(0xFFE3EDE7),
    doing: Color(0xFFFAEFC9),
    review: Color(0xFFDDEBF3),
    done: Color(0xFFCFEBD9),
  );

  static const lavande = ArdoisePalette(
    id: 'lavande',
    name: 'Lavande',
    bg: Color(0xFFF4F1FA),
    bgDot: Color(0xFFE2DBF0),
    surface: Color(0xFFFFFFFF),
    column: Color(0xA6FFFFFF),
    ink: Color(0xFF2E2540),
    muted: Color(0xFF6E6189),
    line: Color(0xFFD9D0EA),
    lineStrong: Color(0xFFB4A6D0),
    accent: Color(0xFF7356B5),
    accentSoft: Color(0xFFE9E1F7),
    accentInk: Color(0xFF5B4296),
    shadowOffset: Color(0xFFB9A6E0),
    project: Color(0xFFE9E1F7),
    unassigned: Color(0xFFECE7F4),
    description: Color(0xFF4A3E60),
    bug: Color(0xFFFBE1E4),
    feature: Color(0xFFE9E1F7),
    idea: Color(0xFFFBF2CC),
    todo: Color(0xFFECE7F4),
    doing: Color(0xFFFBEFC9),
    review: Color(0xFFF3DDEA),
    done: Color(0xFFDCEFD9),
  );

  /// L'ordre du sélecteur. La première est celle par défaut.
  static const all = [argile, ardoise, menthe, lavande];

  static ArdoisePalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => argile);
}

/// Tokens de `docs/design-tokens.json`. Source unique : aucune couleur
/// littérale ailleurs dans `lib/`.
///
/// Les couleurs sont des **getters** sur la palette active (`T.palette`), pas
/// des constantes : c'est ce qui permet de changer de thème. Conséquence : une
/// expression qui en lit une ne peut pas être `const`.
abstract final class T {
  /// La palette active. Seul `ThemeController` la change, puis fait
  /// reconstruire l'app.
  static ArdoisePalette palette = ArdoisePalette.argile;

  // — Couleurs —
  static Color get bg => palette.bg;
  static Color get bgDot => palette.bgDot;
  static Color get surface => palette.surface;
  static Color get column => palette.column;
  static Color get ink => palette.ink;
  static Color get muted => palette.muted;
  static Color get line => palette.line;
  static Color get lineStrong => palette.lineStrong;
  static Color get accent => palette.accent;
  static Color get accentSoft => palette.accentSoft;
  static Color get accentInk => palette.accentInk;
  static Color get shadowOffset => palette.shadowOffset;
  static Color get project => palette.project;
  static Color get unassigned => palette.unassigned;
  static Color get description => palette.description;

  /// Fond des dialogues : l'encre à 18 %.
  static Color get backdrop => palette.ink.withValues(alpha: 0.18);

  /// Contour extérieur des barres (navigation, segment, puces) : plus épais
  /// et plus doux que le contour encre des cartes.
  static Color get softOutline => palette.ink.withValues(alpha: 0.42);
  static const softOutlineWidth = 2.5;

  static const personPalette = <Color>[
    Color(0xFFEFC4A6),
    Color(0xFFCBE4B6),
    Color(0xFFF6E19A),
    Color(0xFFF8C2BC),
    Color(0xFFF8CFA2),
  ];

  /// Couleurs proposées à la création d'un projet. Même famille que les
  /// avatars, en plus désaturé — un projet n'est pas une personne.
  static const projectPalette = <Color>[
    Color(0xFFDDF3EF),
    Color(0xFFFDE7D6),
    Color(0xFFE8E3F5),
    Color(0xFFDDEFD3),
    Color(0xFFFCF1CC),
    Color(0xFFF8D8E4),
  ];

  static Color typeColor(RequestType type) => switch (type) {
    RequestType.bug => palette.bug,
    RequestType.feature => palette.feature,
    RequestType.idea => palette.idea,
  };

  static Color statusColor(RequestStatus status) => switch (status) {
    RequestStatus.todo => palette.todo,
    RequestStatus.doing => palette.doing,
    RequestStatus.review => palette.review,
    RequestStatus.done => palette.done,
  };

  // — Contours —
  static const borderWidth = 1.5;

  // — Rayons —
  static const rNav = 29.0;
  static const rNavItem = 21.0;
  static const rPanel = 26.0;
  static const rColumn = 24.0;
  static const rCard = 20.0;
  static const rChip = 18.0;
  static const rSmallChip = 12.0;

  // — Ombres —
  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadowOffset, offset: const Offset(2, 2)),
    BoxShadow(
      color: accent.withValues(alpha: 0.10),
      offset: const Offset(0, 4),
      blurRadius: 12,
    ),
  ];
  static List<BoxShadow> get navShadow => [
    BoxShadow(
      color: accent.withValues(alpha: 0.12),
      offset: const Offset(0, 4),
      blurRadius: 18,
    ),
  ];
  static List<BoxShadow> get panelShadow => [
    BoxShadow(color: shadowOffset, offset: const Offset(3, 3)),
    BoxShadow(
      color: ink.withValues(alpha: 0.18),
      offset: const Offset(0, 12),
      blurRadius: 40,
    ),
  ];

  // — Tailles de police —
  static const fsPageTitle = 48.0;
  static const fsPanelTitle = 28.0;
  static const fsColumnTitle = 18.0;
  static const fsCardTitle = 17.0;
  static const fsBody = 15.0;
  static const fsSmall = 14.0;
  static const fsMeta = 13.0;
  static const fsTiny = 12.0;

  // — Espacements et gabarits —
  /// Point de rupture unique : en dessous, c'est un téléphone tenu en main.
  /// Un seul seuil — deux suffisent rarement et trois ne se maintiennent pas.
  static const phoneBreakpoint = 600.0;

  static const pagePadding = 24.0;
  static const pagePaddingPhone = 16.0;
  static const fsPageTitlePhone = 32.0;
  static const columnGap = 16.0;
  static const cardPadding = 14.0;
  static const cardGap = 10.0;
  static const columnMinWidth = 250.0;
  static const drawerWidth = 420.0;
  static const dialogWidth = 480.0;
  static const dotSpacing = 20.0;
  static const dotRadius = 1.2;
}
