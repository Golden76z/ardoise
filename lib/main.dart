import 'package:flutter/material.dart';

import 'board_page.dart';
import 'data/repository.dart';
import 'data/store.dart';
import 'theme/app_theme.dart';

void main() {
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
