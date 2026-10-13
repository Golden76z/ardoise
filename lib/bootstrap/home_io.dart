import 'dart:io';

import 'package:flutter/widgets.dart';

import '../data/store.dart';
import '../data/vault_repository.dart';
import '../widgets/vault_gate.dart';
import 'home_local.dart';

/// Bureau : les demandes vivent dans le vault Obsidian. Android garde les
/// préférences — un vault n'y est pas joignable par un chemin.
Future<Widget> buildHome() async {
  if (!(Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    return localHome();
  }
  final saved = await VaultLocation.saved();
  final problem = saved == null ? null : await VaultLocation.check(saved);
  return VaultGate(
    initialPath: saved,
    initialProblem: problem,
    check: VaultLocation.check,
    open: (path) async {
      await VaultLocation.remember(path);
      final store = ArdoiseStore(
        repository: VaultRepository(VaultLocation.normalize(path)),
      );
      await store.init();
      return store;
    },
  );
}
