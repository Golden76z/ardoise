import 'package:flutter/material.dart';

import 'board_page.dart';
import 'data/repository.dart';
import 'data/store.dart';
import 'theme/app_theme.dart';

void main() {
  // `init()` passe par un canal de plateforme (shared_preferences) : sans
  // binding, il lève « Binding has not yet been initialized » et l'app repart
  // des données d'exemple à chaque lancement. Invisible sur le web, où le
  // plugin lit le localStorage sans canal — constaté sur Android le 08/10.
  WidgetsFlutterBinding.ensureInitialized();

  final store = ArdoiseStore(repository: PrefsRepository());
  // Le chargement est asynchrone ; `BoardPage` affiche un indicateur tant que
  // `store.loading` est vrai.
  store.init();
  runApp(ArdoiseApp(store: store));
}

class ArdoiseApp extends StatelessWidget {
  const ArdoiseApp({super.key, required this.store});

  final ArdoiseStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ardoise',
    debugShowCheckedModeBanner: false,
    theme: buildArdoiseTheme(),
    home: BoardPage(store: store),
  );
}
