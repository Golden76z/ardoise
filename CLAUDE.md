# Ardoise

Gestionnaire de demandes (bugs / fonctionnalités / idées) multi-projets.
**Appli de bureau d'abord (Linux, Windows)**, sans backend : sur le bureau, les
demandes vivent dans le **vault Obsidian** de l'utilisateur, une note par
demande. Le web et Android restent possibles, sur les préférences locales.
Un vault de démonstration (données fictives) est dans `exemple/vault-demo` ;
`test/demo_vault_test.dart` garantit qu'il reste lisible.

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

Implémentations : `VaultRepository` (bureau), `PrefsRepository` (web,
Android), `MemoryRepository` (tests). Le choix se fait au démarrage dans
`lib/bootstrap/` : import conditionnel, car `dart:io` ne compile pas pour le
web. **`dart:io` n'apparaît que dans `vault_repository.dart` et
`bootstrap/home_io.dart`.**

## Le vault Obsidian

`lib/data/vault_format.dart` (pur, testé sans disque) décrit le format ;
`lib/data/vault_repository.dart` lit et écrit les fichiers.

```text
<vault>/Ardoise/Ardoise.md            index : `utilisateur` (qui je suis)
<vault>/Ardoise/Personnes/Camille.md  une note par personne
<vault>/Ardoise/WEB/WEB.md            note du projet ; corps libre
<vault>/Ardoise/WEB/WEB-12.md         une demande ; corps = description
```

Propriétés d'une demande : `ardoise: demande`, `numero`, `titre`, `type`
(bug, fonctionnalité, idée), `statut` (à faire, en cours, en revue, fait),
`demandeur`, `intervenant` (liens `[[Personne]]`), `cree`, `priorite` (basse,
moyenne, haute, urgente ; moyenne si absente), `echeance` (`2026-10-09`,
facultative). Les votes ont été
retirés le 13/10 : une ancienne propriété `votes` disparaît à la réécriture.

Règles de la synchronisation — chacune protège des notes réelles :

- **Seules les notes qui portent `ardoise:` sont lues.** Le reste du vault
  n'est jamais touché, ni en lecture ni en écriture.
- **L'app n'écrit que ce qu'elle a changé** depuis la dernière lecture (rendu
  du nouvel état comparé à celui de l'état connu). Ne jamais « réécrire tout
  l'état » : ce serait écraser ce qui vient d'être modifié dans Obsidian.
- **Le disque fait foi** : le dossier est sondé toutes les 2 s (signature
  chemins/dates/tailles) et l'état relu remplace celui du store
  (`externalChanges`). Un sondage plutôt qu'un `watch` : identique sous
  Linux et Windows, et il voit aussi un `git pull`.
- **Lectures et écritures passent par une seule file** : une relecture ne voit
  jamais une sauvegarde à moitié faite. Écritures atomiques (fichier caché
  puis renommage).
- **Lecture en échec ⇒ aucune écriture** (`StateError`). Sinon l'app, repartie
  sur ses données d'exemple, les graverait par-dessus le vrai vault.
- Une valeur illisible (statut inconnu, numéro en double) fait ignorer **cette
  note**, signalée en bandeau — jamais le vault entier, et elle n'est jamais
  supprimée.
- Une note créée à la main avec `ardoise: demande` mais sans numéro est
  **adoptée** à la lecture : numérotée, réécrite en `CLE-n.md`, l'original
  supprimé. Sinon son numéro changerait à chaque lecture.
- Ce qu'on ajoute dans Obsidian (tags, propriétés inconnues, corps des notes
  de projet et de personne) est conservé aux écritures.

Le chemin du vault est retenu dans les préférences (`ardoise.vaultPath`) ; la
variable d'environnement `ARDOISE_VAULT` le force. `VaultGate` le demande au
premier lancement, ou quand le dossier retenu a disparu.

## Commandes

```bash
flutter test            # tout doit être vert
flutter analyze         # doit dire « No issues found! »
dart format lib test
flutter run -d linux    # ou -d windows ; -d chrome pour le web
```

Les dossiers `linux/` et `windows/` se génèrent une fois avec
`flutter create --platforms=linux,windows --org dev.golden .` (ne touche pas à
`lib/`), **puis supprimer `test/widget_test.dart`** qu'il génère (il cherche un
`MyApp` qui n'existe pas). Ne pas commiter `.idea/` ni `ardoise.iml`. Sous
Linux il faut `clang cmake ninja-build pkg-config libgtk-3-dev`.

## Règles

- **Aucune couleur, rayon, ombre ou taille littérale hors `lib/theme/tokens.dart`.**
- **Thèmes.** Les couleurs vivent dans des `ArdoisePalette` (Argile, Ardoise,
  Menthe, Lavande) ; `T.ink`, `T.bg`… et `TextStyles.*` sont des **getters**
  sur la palette active. Donc : **jamais de `const` autour d'une expression
  qui lit une couleur ou un style**, et jamais de couleur en valeur par défaut
  d'un paramètre (rendre le champ nullable et résoudre dans `build`, comme
  `InkOutline.borderColor`). Un `CustomPainter` reçoit sa couleur en
  paramètre, il ne la lit pas dans `paint`. Le changement de thème remonte
  `BoardPage` (clé = id de palette). Le choix est retenu dans les
  préférences (`ardoise.theme`), pas dans le vault. Les couleurs de
  personnes et de projets ne sont pas thémées : ce sont des données.
- **Dates saisies** au format `jj/mm/aaaa` (`parseFrenchDate`) : pas de
  `showDatePicker`, qui demanderait `flutter_localizations` pour parler
  français. Couleurs de priorité fixes (`T.priorityColors`), pas thémées.
- **Contour des barres** (navigation, segment, puces de type) :
  `T.softOutline` / `T.softOutlineWidth`, plus épais et plus doux que l'encre
  des cartes.
- Interface **en français**, libellés d'accessibilité compris.
- Pas de nouvelle dépendance sans accord.
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
