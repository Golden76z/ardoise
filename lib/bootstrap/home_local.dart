import 'package:flutter/widgets.dart';

import '../board_page.dart';
import '../data/repository.dart';
import '../data/store.dart';

/// Web et Android : les données restent dans les préférences locales.
Widget localHome() {
  final store = ArdoiseStore(repository: PrefsRepository());
  // Le chargement est asynchrone ; `BoardPage` affiche un indicateur tant que
  // `store.loading` est vrai.
  store.init();
  return BoardPage(store: store);
}
