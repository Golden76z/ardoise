import 'package:flutter/material.dart';

import 'bootstrap/home_stub.dart'
    if (dart.library.io) 'bootstrap/home_io.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  // Le démarrage passe par des canaux de plateforme (shared_preferences) :
  // sans binding, ils lèvent « Binding has not yet been initialized » et
  // l'app repart des données d'exemple à chaque lancement. Invisible sur le
  // web, où le plugin lit le localStorage sans canal — constaté sur Android
  // le 08/10.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ArdoiseApp(home: await buildHome()));
}

class ArdoiseApp extends StatelessWidget {
  const ArdoiseApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ardoise',
    debugShowCheckedModeBanner: false,
    theme: buildArdoiseTheme(),
    home: home,
  );
}
