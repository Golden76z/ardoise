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
5. **Glisser-déposer** : au doigt la carte ne se saisit qu'à l'**appui long**
   (`LongPressDraggable`), sinon elle accapare le geste et le tableau devient
   impossible à faire défiler sur un téléphone. À la souris, `Draggable`
   immédiat. En test, `defaultTargetPlatform` vaut `android` : il faut tenir
   `kLongPressTimeout` avant de bouger, puis franchir `kTouchSlop`.
6. **Canaux de plateforme avant `runApp`.** `main()` doit appeler
   `WidgetsFlutterBinding.ensureInitialized()` avant tout ce qui touche un
   plugin. Sans ça, `SharedPreferences.getInstance()` lève « Binding has not
   yet been initialized » — **et uniquement sur mobile**, parce que
   l'implémentation web lit le `localStorage` sans canal. Résultat vécu : les
   données étaient bien écrites et jamais relues, l'app repartait des données
   d'exemple à chaque lancement, et **104 tests verts n'y voyaient rien**.
7. **Ne jamais confondre « rien d'enregistré » et « lecture en panne ».** Le
   `null` de `load()` cachait le bug ci-dessus pendant une journée. D'où
   `ArdoiseRepository.lastLoadError`, que `ArdoiseStore.init` remonte en
   bandeau. Un silence sur une panne de lecture finit en perte de données :
   la première écriture grave les données d'exemple par-dessus le vrai travail.

8. **Un `Row(mainAxisSize: .min)` ne replie rien.** Remplacer un `Wrap` par
   une rangée décidée donne une meilleure mise en page, mais tout contenu de
   largeur non bornée doit alors être `Flexible` avec `maxLines` et
   `overflow: ellipsis`. `createProject` borne la clé à 5 caractères, **pas le
   nom** : sans ellipsis, un projet au nom un peu long fait déborder la barre
   de navigation. Même règle pour tout `Text` dans une boîte à hauteur figée,
   qui serait sinon coupé en silence à grande échelle de police.
9. **Un libellé visible retiré est aussi retiré au lecteur d'écran.** Le
   segment perd son titre au téléphone : il le garde en `Semantics(label:)`.
   Et quand un bouton porte un `semanticLabel`, son texte visible est
   décoratif — `ExcludeSemantics`, sinon le lecteur annonce « Nouvelle
   demande, + ».

10. **Tout libellé dans une pilule est abrégeable.** `PillButton` et
    `_NavChip` mettent leur `Text` en `Flexible` + `maxLines: 1` + ellipsis.
    Sans ça, « Nouvelle personne » dans un menu étroit déborde en dur. Idem
    pour les largeurs figées : un panneau de 340 px sur un écran de 280 doit
    se borner à la largeur disponible.

## Responsive

Un seul point de rupture : `T.phoneBreakpoint` (600 px), lu par
`isPhone(context)`. Il ne gouverne que **l'habillage de la page** — barre de
navigation, titre, marges, segment, lignes de liste.

Au téléphone la barre de navigation tient **sur une ligne**, contenu centré,
et prend toute la largeur : c'est ce qui donne au `Flexible` de la pilule de
projet une place à céder. Dans un `Row(mainAxisSize: .min)`, un `Flexible` ne
rétrécit jamais — la rangée se dimensionne sur ses enfants. Le prix de la
ligne unique : le logo (décoratif) disparaît, et le sélecteur de mois descend
dans l'en-tête. Tout ce qui porte du texte dans cette rangée est `Flexible` +
ellipsis, pour que rien ne déborde quelle que soit l'échelle de police. Les panneaux (tiroir,
dialogue de création, menu de projet) se replient déjà correctement d'eux-mêmes
et n'ont pas de branche téléphone. `test/responsive_test.dart` monte l'app de
280 à 1440 px.

## Vérifier

Les tests de widget et le navigateur ne couvrent pas tout. Avant de déclarer
une fonctionnalité finie, **la lancer sur un vrai téléphone** :

```bash
flutter run -d <id>                       # `flutter devices` pour l'id
adb exec-out screencap -p > /tmp/x.png    # regarder le résultat
adb shell am force-stop dev.golden.ardoise && \
  adb shell monkey -p dev.golden.ardoise -c android.intent.category.LAUNCHER 1
```

Le redémarrage à froid **sans réinstallation** est le seul test qui prouve
que la persistance tient. `flutter run` réinstalle l'APK et masque le
problème.
