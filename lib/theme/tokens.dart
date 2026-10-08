import 'package:flutter/painting.dart';

import '../models/models.dart';

/// Tokens de `docs/design-tokens.json`. Source unique : aucune couleur
/// littérale ailleurs dans `lib/`.
abstract final class T {
  // — Couleurs —
  static const bg = Color(0xFFFFF4EC);
  static const bgDot = Color(0xFFF1DCCB);
  static const surface = Color(0xFFFFFFFF);
  static const column = Color(0xA6FFFFFF); // blanc à 65 %
  static const ink = Color(0xFF4A2E22);
  static const muted = Color(0xFF8A5F48);
  static const line = Color(0xFFE2C3AE);
  static const lineStrong = Color(0xFFC9A58E);
  static const accent = Color(0xFFB4532A);
  static const accentSoft = Color(0xFFFBE3D4);
  static const accentInk = Color(0xFF9A4320);
  static const shadowOffset = Color(0xFFE39A74);
  static const project = Color(0xFFDDF3EF);
  static const unassigned = Color(0xFFEFE3D8);
  static const description = Color(0xFF6E4A38); // `.desc` du prototype
  static const backdrop = Color(0x2E4A2E22); // rgba(74,46,34,0.18)

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
    RequestType.bug => const Color(0xFFFDE1DC),
    RequestType.feature => const Color(0xFFFDE7D6),
    RequestType.idea => const Color(0xFFFCF1CC),
  };

  static Color statusColor(RequestStatus status) => switch (status) {
    RequestStatus.todo => const Color(0xFFF3E6DB),
    RequestStatus.doing => const Color(0xFFFCEBC4),
    RequestStatus.review => const Color(0xFFF9DCCB),
    RequestStatus.done => const Color(0xFFDDEFD3),
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
  static const cardShadow = <BoxShadow>[
    BoxShadow(color: shadowOffset, offset: Offset(2, 2)),
    BoxShadow(color: Color(0x1AB4532A), offset: Offset(0, 4), blurRadius: 12),
  ];
  static const navShadow = <BoxShadow>[
    BoxShadow(color: Color(0x1FB4532A), offset: Offset(0, 4), blurRadius: 18),
  ];
  static const panelShadow = <BoxShadow>[
    BoxShadow(color: shadowOffset, offset: Offset(3, 3)),
    BoxShadow(color: Color(0x2E4A2E22), offset: Offset(0, 12), blurRadius: 40),
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
