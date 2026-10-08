# Ardoise

Un suivi de demandes léger, pour plusieurs projets à la fois. Ce qu'on a sur
l'ardoise : les bugs, les fonctionnalités et les idées, qui les demande et qui
s'en occupe.

Flutter — web et Android. **Aucun serveur** : tout est enregistré localement.

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

## Démarrer

```bash
flutter pub get
flutter run -d chrome
```

```bash
flutter test      # 101 tests
flutter analyze
```

## Comment c'est fait

Trois couches, et la frontière entre elles n'est pas négociable.

| Dossier | Rôle |
|---|---|
| `lib/models/` | Domaine pur. Aucun import Flutter hors `Color`. |
| `lib/data/` | Un unique `ArdoiseStore` (`ChangeNotifier`) derrière l'interface `ArdoiseRepository`. |
| `lib/widgets/` | Ne fait que lire le store et le notifier. Aucun filtrage ni tri ici. |

La persistance est un document JSON dans les préférences locales — identique
sur web et mobile, contrairement à SQLite qui réclame un worker wasm sur le
web. Le jour où une API arrive, on écrit une autre implémentation de
`ArdoiseRepository` et rien d'autre ne bouge.

Le design vient de `docs/prototype.html`, qui reste la référence visuelle et
comportementale, et de `docs/design-tokens.json`, d'où sortent **toutes** les
couleurs, rayons et ombres.

`CLAUDE.md` consigne les pièges du projet, et `docs/superpowers/plans/` les
plans d'implémentation.

## Ce qu'il ne fait pas encore

Pas de comptes ni d'authentification, pas de partage entre appareils (chaque
navigateur a ses propres données), pas de vue Votes, pas de commentaires ni de
pièces jointes. Tout cela attend une API ; le modèle de données la prévoit
déjà.

## Licence

MIT.
