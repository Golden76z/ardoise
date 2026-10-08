import 'package:flutter/material.dart';

import 'board_page.dart';
import 'data/repository.dart';
import 'data/store.dart';
import 'theme/app_theme.dart';

void main() {
  final store = ChantierStore(repository: PrefsRepository());
  // Le chargement est asynchrone ; `BoardPage` affiche un indicateur tant que
  // `store.loading` est vrai.
  store.init();
  runApp(ChantierApp(store: store));
}

class ChantierApp extends StatelessWidget {
  const ChantierApp({super.key, required this.store});

  final ChantierStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Chantier',
    debugShowCheckedModeBanner: false,
    theme: buildChantierTheme(),
    home: BoardPage(store: store),
  );
}
