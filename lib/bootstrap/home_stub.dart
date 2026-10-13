import 'package:flutter/widgets.dart';

import 'home_local.dart';

/// Web : pas de `dart:io`, donc pas de vault.
Future<Widget> buildHome() async => localHome();
