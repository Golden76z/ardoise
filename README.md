# Ardoise

Un suivi de demandes léger, pour plusieurs projets à la fois. Ce qu'on a sur
l'ardoise : les bugs, les fonctionnalités et les idées, qui les demande et qui
s'en occupe.

Flutter, **appli de bureau** (Linux, Windows) branchée sur ton **vault
Obsidian** : chaque demande y est une note, modifiable dans l'app comme dans
Obsidian, et les deux restent d'accord. **Aucun serveur.** Le web et Android
fonctionnent aussi, avec un stockage local.

![Capture du tableau](docs/prototype.html)

## Ce que ça fait

- **Tableau** groupable au choix par **statut**, **intervenant** ou
  **demandeur**, avec glisser-déposer des cartes entre colonnes.
- **Vue Liste** tous mois confondus, avec recherche plein texte et tri par
  date, votes ou statut — pour retrouver une demande ancienne que le tableau,
  filtré par mois, ne montre plus.
- **Plusieurs projets**, chacun avec sa clé (`ECH-42`), sa couleur et sa
  numérotation propre.
- **Filtres** par type et par mois, **votes** (un par personne et par demande),
  panneau de détail pour changer le statut et réassigner.
- **Obsidian** : un dossier `Ardoise/` dans le vault, un sous-dossier par
  projet, une note par demande (propriétés + description). Une note créée
  dans Obsidian avec `ardoise: demande` devient une demande ; une
  modification faite dans Obsidian (ou par un `git pull`) apparaît dans l'app
  en deux secondes.

## Démarrer

```bash
flutter create --platforms=linux,windows --org dev.golden .   # une fois
flutter pub get
flutter run -d linux        # ou -d windows
```

Au premier lancement, l'app demande le dossier de ton vault (celui qui
contient `.obsidian`). `ARDOISE_VAULT=/chemin/du/vault` le force.

```bash
flutter test
flutter analyze
```

## Comment c'est fait

Trois couches, et la frontière entre elles n'est pas négociable.

| Dossier | Rôle |
|---|---|
| `lib/models/` | Domaine pur. Aucun import Flutter hors `Color`. |
| `lib/data/` | Un unique `ArdoiseStore` (`ChangeNotifier`) derrière l'interface `ArdoiseRepository`. |
| `lib/widgets/` | Ne fait que lire le store et le notifier. Aucun filtrage ni tri ici. |

Sur le bureau, la persistance est le vault Obsidian (`VaultRepository`) ;
sur le web et Android, un document JSON dans les préférences locales. Le jour où une API arrive, on écrit une autre implémentation de
`ArdoiseRepository` et rien d'autre ne bouge.

Le design vient de `docs/prototype.html`, qui reste la référence visuelle et
comportementale, et de `docs/design-tokens.json`, d'où sortent **toutes** les
couleurs, rayons et ombres.

`CLAUDE.md` consigne les pièges du projet, et `docs/superpowers/plans/` les
plans d'implémentation.

## Ce qu'il ne fait pas encore

Pas de comptes ni d'authentification ; le partage entre appareils passe par
la synchronisation du vault (Git), pas par l'app. Pas de vue Votes, pas de commentaires ni de
pièces jointes. Tout cela attend une API ; le modèle de données la prévoit
déjà.

## Licence

MIT.
