import 'package:flutter/material.dart';

import '../board_page.dart';
import '../data/store.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'primitives.dart';

/// Devant le tableau, sur le bureau : tant qu'aucun vault Obsidian valide
/// n'est choisi, on demande où il est. Le widget ne touche pas au disque —
/// `check` et `open` viennent de `VaultLocation`, côté données.
class VaultGate extends StatefulWidget {
  const VaultGate({
    super.key,
    required this.check,
    required this.open,
    this.initialPath,
    this.initialProblem,
  });

  /// `null` si le chemin est utilisable, sinon le motif à afficher.
  final Future<String?> Function(String path) check;

  /// Retient le chemin et rend le store branché dessus, déjà lancé.
  final Future<ArdoiseStore> Function(String path) open;

  /// Chemin retenu au lancement précédent ; ouvert d'office s'il est valide.
  final String? initialPath;

  /// Pourquoi le chemin retenu n'est plus utilisable (vault déplacé…).
  final String? initialProblem;

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> {
  late final TextEditingController _path = TextEditingController(
    text: widget.initialPath ?? '',
  );
  ArdoiseStore? _store;
  String? _problem;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _problem = widget.initialProblem;
    if (widget.initialPath != null && widget.initialProblem == null) {
      // Pas de `setState` dans `initState` : on pose l'état directement.
      _busy = true;
      _run();
    }
  }

  @override
  void dispose() {
    _path.dispose();
    _store?.dispose();
    super.dispose();
  }

  void _submit() {
    if (_busy) return;
    setState(() => _busy = true);
    _run();
  }

  Future<void> _run() async {
    final problem = await widget.check(_path.text);
    if (!mounted) return;
    if (problem != null) {
      setState(() {
        _problem = problem;
        _busy = false;
      });
      return;
    }
    final store = await widget.open(_path.text);
    if (!mounted) {
      store.dispose();
      return;
    }
    setState(() {
      _store = store;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null) return BoardPage(store: store);
    // Lancement avec un vault déjà retenu : pas de formulaire qui clignote.
    if (_busy && widget.initialPath != null && _problem == null) {
      return const Scaffold(
        backgroundColor: T.bg,
        body: Center(child: CircularProgressIndicator(color: T.accent)),
      );
    }

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: T.ink, width: T.borderWidth),
    );
    return Scaffold(
      backgroundColor: T.bg,
      body: DottedBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: T.dialogWidth),
                child: InkOutline(
                  radius: T.rPanel,
                  color: T.surface,
                  shadow: T.panelShadow,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Où est ton vault ?', style: TextStyles.panelTitle),
                      const SizedBox(height: 10),
                      const Text(
                        'Ardoise range ses demandes dans un dossier « Ardoise » '
                        'de ton vault Obsidian : une note par demande, que tu '
                        'peux aussi modifier depuis Obsidian.',
                        style: TextStyles.sub,
                      ),
                      const SizedBox(height: 16),
                      const Text('Dossier du vault', style: TextStyles.label),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _path,
                        autofocus: true,
                        enabled: !_busy,
                        onSubmitted: (_) => _submit(),
                        style: TextStyles.body.copyWith(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Ex. : ~/Documents/Notes',
                          hintStyle: TextStyles.sub,
                          filled: true,
                          fillColor: T.bg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                          ),
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border.copyWith(
                            borderSide: const BorderSide(
                              color: T.accent,
                              width: T.borderWidth,
                            ),
                          ),
                        ),
                      ),
                      if (_problem != null) ...[
                        const SizedBox(height: 10),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _problem!,
                            style: TextStyles.sub.copyWith(color: T.accentInk),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: PillButton(
                              label: 'Ouvrir ce vault',
                              onPressed: _busy ? null : _submit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
