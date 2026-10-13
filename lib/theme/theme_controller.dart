import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tokens.dart';

/// Le thème de couleurs choisi. Retenu dans les préférences de l'appareil,
/// pas dans le vault : c'est un goût d'affichage, pas une donnée partagée.
///
/// Les couleurs de `T` sont lues pendant le `build` : changer de palette
/// demande de tout reconstruire. `BoardPage` écoute ce contrôleur et remonte
/// son sous-arbre (clé = id de palette), ce qui atteint aussi les widgets
/// `const` et les peintres qui n'auraient pas su se repeindre.
class ThemeController extends ChangeNotifier {
  ThemeController._();

  static final instance = ThemeController._();

  static const preferenceKey = 'ardoise.theme';

  ArdoisePalette get palette => T.palette;

  /// À appeler avant `runApp`, après `ensureInitialized`. Ne lève jamais :
  /// sans préférences lisibles, on garde la palette par défaut.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      T.palette = ArdoisePalette.byId(prefs.getString(preferenceKey));
    } on Object {
      T.palette = ArdoisePalette.all.first;
    }
  }

  void select(ArdoisePalette palette) {
    if (palette.id == T.palette.id) return;
    T.palette = palette;
    notifyListeners();
    _save(palette.id);
  }

  Future<void> _save(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(preferenceKey, id);
    } on Object {
      // Le thème reste appliqué pour la session ; seul le souvenir est perdu.
    }
  }
}
