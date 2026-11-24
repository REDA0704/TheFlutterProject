# The Flutter Project

Plateforme d'évaluation en ligne : les candidats passent des tests
(Java, Algo, HTML/CSS) et les administrateurs suivent les résultats.

Application Flutter, base de données SQLite locale (`sqflite`).
L'espace candidat et l'espace administrateur sont dans la même
application : l'admin voit les résultats des candidats qui ont passé
leurs tests sur le même appareil.

## Lancer le projet
1. `git clone https://github.com/REDA0704/TheFlutterProject.git`
2. `flutter pub get`
3. `flutter run` (Android de préférence ; Windows et Linux passent par
   `sqflite_common_ffi`)
4. `flutter test` pour lancer les tests

> Sous Windows, `flutter pub get` demande d'activer le **mode développeur**
> (`start ms-settings:developers`) pour les plugins.

## Compte administrateur
Créé automatiquement au premier lancement (US4) :

| Identifiant | Mot de passe |
|-------------|--------------|
| `admin`     | `admin123`   |

Ce mot de passe par défaut est connu de tous : **il doit être changé à la
première connexion** (écran obligatoire), puis à tout moment avec l'icône
🔑 de l'espace admin. Les mots de passe (admin et candidats) sont stockés
**hachés** (SHA-256 + sel aléatoire), jamais en clair
(`lib/utils/securite.dart`).

Après **5 mots de passe faux** de suite, la connexion (admin ou candidat)
est bloquée **30 secondes**.

## Fonctionnalités (user stories)

| US  | Rôle      | Fonction | Écran principal |
|-----|-----------|----------|-----------------|
| US1 | Candidat  | Inscription (un compte par email, mot de passe) et connexion email + mot de passe | `screens/candidat/inscription_screen.dart` |
| US2 | Candidat  | Passer un test chronométré, une seule fois par discipline | `screens/candidat/passer_test_screen.dart` |
| US3 | Candidat  | Profil : scores, adresse et motivation modifiables | `screens/candidat/profil_screen.dart` |
| US4 | Admin     | Connexion avec le compte pré-existant | `screens/admin/login_admin_screen.dart` |
| US5 | Admin     | Ajouter / modifier / supprimer des questions, import JSON | `screens/admin/questions/` |
| US6 | Admin     | Tableau de bord : derniers résultats, recherche, filtre par année | `screens/admin/resultats_screen.dart` |
| US7 | Admin     | Camemberts de réussite par discipline et global par année | `screens/admin/statistiques_screen.dart` |

## Règles métier
- **Compte unique** : contrainte `UNIQUE (email)` sur `candidats` (en plus
  de `UNIQUE (nom, email)` demandée par l'US1). Sans elle, un candidat
  pourrait créer un 2e compte en changeant l'orthographe de son nom
  (« DUPONT » / « DUPOND ») et repasser tous les tests. Le nom est
  enregistré en majuscules et l'email en minuscules.
- **Mot de passe candidat** : 8 caractères minimum, une lettre et un
  chiffre. Sans lui, connaître le nom et l'email de quelqu'un suffisait
  pour passer les tests à sa place. Un compte créé avant cette règle
  définit son mot de passe à la connexion en confirmant son nom.
- **Un seul passage par test** : contrainte `UNIQUE (candidat_id, discipline)`
  sur `resultats`. La tentative est enregistrée **dès le début du test**
  (score 0) puis le score est mis à jour après chaque question. Quitter le
  test, fermer l'appli ou éteindre le téléphone ne permet donc pas de le
  recommencer : les questions non répondues comptent comme fausses.
- **Test en cours / interrompu** : un test commencé est « en cours »
  (affiché en orange dans le tableau de bord) et **ne compte pas** dans
  les statistiques. Il devient définitif à la dernière question, en cas
  d'abandon, ou automatiquement une fois sa durée maximale dépassée
  (somme des temps limites + 2 min) si l'appli a été fermée.
- **Mélange** : l'ordre des questions et des réponses change pour chaque
  candidat, pour qu'ils ne puissent pas se donner « c'est la B ».
- **Temps limite** : chaque question a son propre chrono (5 à 600 s).
  Temps écoulé = question fausse, on passe à la suivante.
- **Correction** : une réponse est juste si toutes les bonnes options, et
  seulement elles, sont cochées.
- **Réussite** : un test est réussi à partir de **50 %** de bonnes réponses
  (`DatabaseService.seuilReussite`).
- **Année scolaire** : de septembre à août (ex. `2026-2027`). Les filtres
  US6 et US7 utilisent l'année **où le test a été passé** (et non celle de
  l'inscription : un candidat inscrit en juin et évalué en octobre compte
  pour la nouvelle année).
- **Recherche (US6)** : chaque mot doit se trouver dans le nom ou le
  prénom ; « Lucas DEMOALPHA » ou « demoalpha lucas » fonctionnent.
- **Taux de réussite (US7)** : par discipline, c'est la part des tests
  réussis. Le camembert général compte les **étudiants** : chacun compte
  une fois et est reçu si l'ensemble de ses tests atteint 50 %.
- **Import JSON** (US5) : remplace toute une discipline dans une
  transaction (tout ou rien). Format : `docs/exemple_questions.json`.
- **Questions de départ** : 5 questions par discipline sont insérées au
  premier lancement pour qu'un candidat puisse passer un test tout de suite.

## Base de données
`lib/services/database_service.dart` – schéma version 3 :

| Table | Colonnes principales |
|---|---|
| `candidats` | nom, prenom, email (unique), age, adresse, motivation, annee_scolaire (inscription), mot_de_passe (hash), sel |
| `questions` | discipline, enonce, type (`radio` / `checkbox`), options (JSON), bonnes_reponses (JSON), temps_limite |
| `resultats` | candidat_id, discipline, score, total, date, annee_scolaire (du test), termine, date_limite |
| `admins` | login, mot_de_passe (hash), sel |

Une base créée par une ancienne version est migrée automatiquement, sans
perdre les candidats ni les résultats.

## Équipe
- Dosseh APETI (Scrum Master) – US1, US5
- Reda – base SQLite, US4
- Ichan – US2, US3
- Ariela – US6, US7

## Organisation
- Une branche par user story : `feature/usX-...`, relue par un coéquipier
- Commits : `feat(USx):`, `fix(USx):`, `test:`, `docs:`
