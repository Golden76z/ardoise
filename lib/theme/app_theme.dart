import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Le design est entièrement custom : le thème ne porte que la police, le fond
/// et les couleurs de base. Chaque widget se style depuis `T`.
ThemeData buildChantierTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: T.accent,
      primary: T.accent,
      surface: T.surface,
      onSurface: T.ink,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: T.bg,
  );

  // `GoogleFonts.sourGummyTextTheme` renvoie le `TextTheme` de
  // `package:material_ui` (google_fonts 9), incompatible avec celui de
  // Flutter : on prend la famille d'un `TextStyle` et on l'applique.
  final sourGummy = GoogleFonts.sourGummy();

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: sourGummy.fontFamily,
      fontFamilyFallback: sourGummy.fontFamilyFallback,
      bodyColor: T.ink,
      displayColor: T.ink,
    ),
    // Le fond pointillé est peint par `DottedBackground`, pas par le thème.
    canvasColor: T.bg,
    dividerColor: T.line,
    splashFactory: InkSparkle.splashFactory,
  );
}

/// Styles de texte récurrents, pour ne pas répéter `fontWeight: w800` partout.
abstract final class TextStyles {
  static const bold800 = TextStyle(fontWeight: FontWeight.w800, color: T.ink);

  static const pageTitle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: T.fsPageTitle,
    height: 1,
    color: T.ink,
  );
  static const panelTitle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: T.fsPanelTitle,
    height: 1.15,
    color: T.ink,
  );
  static const columnTitle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: T.fsColumnTitle,
    color: T.ink,
  );
  static const cardTitle = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: T.fsCardTitle,
    height: 1.25,
    color: T.ink,
  );
  static const body = TextStyle(fontSize: T.fsBody, color: T.ink);
  static const description = TextStyle(
    fontSize: T.fsBody,
    height: 1.5,
    color: T.description,
  );
  static const sub = TextStyle(fontSize: T.fsSmall, color: T.muted);
  static const meta = TextStyle(fontSize: T.fsMeta, color: T.muted);
  static const label = TextStyle(
    fontSize: T.fsMeta,
    fontWeight: FontWeight.w800,
    color: T.muted,
  );
}
