# Ardoise — dossier de passation

Petite appli de gestion de projet, réutilisable sur plusieurs projets, centrée sur les **demandes** (bugs, fonctionnalités, idées), les personnes qui les **demandent** et celles qui les **traitent**.

Ce dossier contient tout ce qu'il faut pour démarrer l'implémentation :

| Fichier | Rôle |
|---|---|
| `README.md` | Ce document : périmètre, modèle de données, comportements, design. |
| `prototype.html` | Prototype de référence, autonome (HTML + JS vanilla). Ouvre-le dans un navigateur : c'est la source de vérité visuelle et comportementale. |
| `design-tokens.json` | Couleurs, typo, bordures, rayons, ombres, tailles. |

---

## 1. Périmètre de la V1

### Vue « Tableau » d'un projet
- Barre de navigation en **pilule flottante**, centrée : logo, sélecteur de projet, onglets de vue (Tableau / Liste / Votes), **sélecteur de mois** (‹ Octobre 2026 ›), bouton « + Demande ».
- En-tête : nom du projet en grand, sous-titre « N demandes en {mois} · Jalon {nom} · {progression} % ».
- **Organisation des colonnes au choix** (fonctionnalité clé) :
  - **Statut** : À faire · En cours · En revue · Fait.
  - **Intervenant** : une colonne par personne assignée, plus une colonne « Non assigné ».
  - **Demandeur** : une colonne par personne ayant fait la demande.
- En mode Intervenant ou Demandeur, une barre permet d'**afficher ou masquer chaque personne** (une colonne par personne cochée).
- **Filtres par type** (Bugs / Fonct. / Idées), cumulables, avec le nombre de demandes du mois pour chaque type.
- **Filtre par mois** sur la date de création ; le tableau et les compteurs suivent.
- Colonne vide : message « Rien ce mois-ci ».

### Carte de demande
- Fond coloré selon le **type**, contour fin brun, ombre décalée abricot.
- Ligne du haut : `ECH-42 · 1 oct.` et bouton de vote `▲ 7`.
- Titre (cliquable, ouvre le détail).
- Pied : pastille du **demandeur** (avatar + prénom) ; selon le mode de colonnes, on ajoute :
  - le **statut** (quand les colonnes ne sont pas par statut) ;
  - l'**intervenant** en avatar pointillé (quand les colonnes ne sont pas par intervenant).

### Panneau de détail (tiroir à droite)
- Type, identifiant, date, titre, description.
- **Changer le statut** (4 boutons).
- **Réassigner l'intervenant** (une personne ou « Personne »).
- Demandeur, avatars des votants, bouton de vote.
- Toute modification est reflétée immédiatement dans le tableau (la carte change de colonne si besoin).
- Fermeture : bouton ✕, clic sur le fond, touche Échap.

### Création d'une demande (fenêtre modale)
- Champs : titre (obligatoire), type, intervenant.
- La demande est créée dans le mois affiché, au statut « À faire », avec l'utilisateur courant comme demandeur.
- Entrée valide, Échap annule.

### Votes
- Un clic sur ▲ ajoute un vote et ajoute l'utilisateur courant aux votants. En V1 réelle : **un vote par personne et par demande** (bascule voter / retirer son vote).

---

## 2. Modèle de données proposé

```text
Person
  id            uuid
  name          string
  color         string (hex)          -- couleur d'avatar
  initials      string (dérivé)

Project
  id            uuid
  key           string                -- préfixe des identifiants, ex. "ECH"
  name          string
  description   string
  color         string (hex)
  nextNumber    int                   -- compteur pour ECH-58, ECH-59…

Milestone
  id            uuid
  projectId     uuid → Project
  name          string                -- ex. "v0.4"
  dueDate       date
  -- progression = demandes "done" / total des demandes du jalon

Request  (une « demande »)
  id            uuid
  projectId     uuid → Project
  number        int                   -- affiché "ECH-{number}"
  title         string
  description   text
  type          enum  bug | feature | idea
  status        enum  todo | doing | review | done
  requesterId   uuid → Person         -- « Demandé par »
  assigneeId    uuid → Person | null  -- « Intervenant »
  milestoneId   uuid → Milestone | null
  createdAt     timestamp             -- sert au filtre par mois
  updatedAt     timestamp

Vote
  requestId     uuid → Request
  personId      uuid → Person
  createdAt     timestamp
  PRIMARY KEY (requestId, personId)   -- un vote par personne
```

Le nombre de votes affiché est `count(Vote)` pour la demande.

### Requêtes utiles
- Tableau : `Request` du projet, filtrées par mois de `createdAt` et par `type`, groupées par `status`, `assigneeId` ou `requesterId`.
- Compteurs par type : même filtre de mois, sans le filtre de type.

---

## 3. Design (style « Mix 1 »)

Ambiance : douce et chaleureuse, palette pêche / terracotta, contours fins brun chocolat, police arrondie. Détail complet dans `design-tokens.json`.

- **Police** : Sour Gummy (Google Fonts), graisses 400 / 600 / 800. Titres en 800.
- **Fond** : `#FFF4EC` avec un motif de petits points `#F1DCCB` tous les 20 px.
- **Encre** : `#4A2E22` (texte et contours), texte secondaire `#8A5F48`.
- **Accent** : terracotta `#B4532A` (bouton principal, onglet de colonnes actif), version douce `#FBE3D4` / `#9A4320`.
- **Contours** : 1,5 px `#4A2E22`, en pointillés `#C9A58E` pour les éléments désactivés.
- **Ombres** : cartes `2px 2px 0 #E39A74` + ombre floue légère ; panneaux `3px 3px 0 #E39A74` + ombre floue.
- **Rayons** : pilule 29, colonnes 24, cartes 20, panneaux 26, puces 18.
- **Couleurs de type** : bug `#FDE1DC`, fonctionnalité `#FDE7D6`, idée `#FCF1CC`.
- **Couleurs de statut** : à faire `#F3E6DB`, en cours `#FCEBC4`, en revue `#F9DCCB`, fait `#DDEFD3`.
- **Avatars** : rond, initiale, fond pastel propre à chaque personne, contour 1,5 px (pointillé pour l'intervenant sur les cartes).
- **Responsive** : la pilule passe sur plusieurs lignes, le tableau défile horizontalement (colonnes de 250 px minimum).
- **Accessibilité** : vrais `<button>`, `aria-pressed` sur les bascules, `aria-label` sur les boutons à icône, focus visible, contraste du texte ≥ 4,5:1.

---

## 4. Hors périmètre V1 (pistes suivantes)

- Vues **Liste** et **Votes** (présentes dans la navigation mais non actives).
- Plusieurs projets (le sélecteur de projet est visuel pour l'instant).
- Glisser-déposer des cartes entre colonnes.
- Sous-tâches, commentaires, pièces jointes.
- Lien Git (fermer une demande avec `fix #42` dans un commit), changelog automatique.
- Formulaire public pour que des testeurs soumettent des demandes.
- Comptes utilisateurs et authentification.
- Version mobile dédiée et capture rapide.

---

## 5. Stack

À décider avec Damien avant de coder. Piste cohérente avec ses habitudes : **Flutter** (web + mobile) pour l'interface, **Go** pour l'API, **SQLite** puis **PostgreSQL** pour la base. Une version web simple (par exemple Go + HTMX, ou une SPA) est aussi possible pour aller vite.

---

## 6. Prompt de départ pour Claude Code

> Lis `README.md`, `design-tokens.json` et ouvre `prototype.html` : c'est la référence visuelle et fonctionnelle de l'appli « Ardoise ».
> Avant de coder, propose-moi une stack (en tenant compte de la section 5), une arborescence de projet et un plan d'implémentation par étapes pour la V1 décrite en section 1, avec le modèle de données de la section 2.
> Reproduis fidèlement le design (section 3 et tokens). Commence par le modèle de données et l'API, puis la vue Tableau avec le choix des colonnes (Statut / Intervenant / Demandeur), le filtre par mois, les filtres par type, le panneau de détail, la création de demande et les votes.
