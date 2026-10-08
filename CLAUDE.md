# Ardoise

Gestionnaire de demandes (bugs / fonctionnalités / idées) multi-projets.
Flutter web + Android, **sans backend** : tout est local.

- `docs/handoff.md` — le périmètre et le modèle de données d'origine.
- `docs/prototype.html` — la **référence visuelle et comportementale**. En cas
  de doute sur une mesure ou un comportement, c'est lui qui tranche.
- `docs/design-tokens.json` — la source de toutes les valeurs de style.
- `docs/superpowers/plans/` — les plans d'implémentation, par date.

## Architecture

Trois couches, et la frontière entre elles n'est pas négociable.

- `lib/models/` — domaine pur. Aucun import Flutter hors `Color`.
- `lib/data/` — un unique `ArdoiseStore` (`ChangeNotifier`) qui porte l'état,
  les filtres et les mutations, derrière l'interface `ArdoiseRepository`.
  **Aucun filtrage ni tri dans les widgets** : le store sort des données déjà
  prêtes (`columns`, `listRequests`, `visibleRequests`).
- `lib/widgets/` — ne fait que lire le store et le notifier.

Le jour où une API arrive, on écrit une implémentation de `ArdoiseRepository`
et rien d'autre ne bouge. C'est la seule raison d'être de cette interface.

## Commandes

```bash
flutter test            # tout doit être vert
flutter analyze         # doit dire « No issues found! »
dart format lib test
flutter run -d chrome
```

## Règles

- **Aucune couleur, rayon, ombre ou taille littérale hors `lib/theme/tokens.dart`.**
- Interface **en français**, libellés d'accessibilité compris.
- Pas de nouvelle dépendance sans accord.
- Un vote par personne et par demande : `votes == voterIds.length`.
- **Le numéro d'une demande n'est unique qu'à l'intérieur d'un projet.** Toute
  lecture et toute écriture se font sur le couple (projet courant, numéro).
  L'oublier a déjà provoqué des modifications croisées entre projets.

## Pièges de ce projet, appris à la dure

1. **Contraintes lâches.** Dans un `Wrap` (ou tout parent qui donne des
   contraintes lâches), `Align`, `Center` et `Container(alignment:)`
   **s'étirent à toute la largeur disponible**. Ce piège a cassé la barre de
   navigation, la pastille de statut des cartes et le segment « Colonnes »,
   à chaque fois **sans qu'aucun test ne le voie**. Utiliser
   `Center(widthFactor: 1)` ou `Row(mainAxisSize: MainAxisSize.min)`.
   Corollaire : **une mise en page n'est pas vérifiée tant qu'elle n'a pas été
   regardée dans un navigateur.** Les tests de widget ne mesurent pas ça.
2. **`google_fonts`** : ne jamais appeler un `*TextTheme` (il renvoie le
   `TextTheme` de `package:material_ui`, incompatible avec `ThemeData`).
   Seulement `GoogleFonts.sourGummy(...)`, via `textTheme.apply(fontFamily:)`.
3. **`showGeneralDialog` n'a pas de `Material` ancêtre** : un `TextField` ou un
   `InkWell` dans un dialogue en réclame un (`Material(type: transparency)`).
4. **Matchers de sémantique** : `hasFlag` et `containsSemantics` sont
   dépréciés. Utiliser `isSemantics(...)`.
5. **Glisser-déposer en test** : un geste doit franchir `kTouchSlop` avant
   d'être reconnu. Dans un vrai navigateur, un glisser trop rapide n'est pas
   détecté non plus — donner une durée au geste.
