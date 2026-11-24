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

Le mot de passe est stocké **haché** (SHA-256 + sel aléatoire), jamais en
clair (`lib/utils/securite.dart`).

## Fonctionnalités (user stories)

| US  | Rôle      | Fonction | Écran principal |
|-----|-----------|----------|-----------------|
| US1 | Candidat  | Inscription (compte unique Nom + Email) et connexion | `screens/candidat/inscription_screen.dart` |
| US2 | Candidat  | Passer un test chronométré, une seule fois par discipline | `screens/candidat/passer_test_screen.dart` |
| US3 | Candidat  | Profil : scores, adresse et motivation modifiables | `screens/candidat/profil_screen.dart` |
| US4 | Admin     | Connexion avec le compte pré-existant | `screens/admin/login_admin_screen.dart` |
| US5 | Admin     | Ajouter / modifier / supprimer des questions, import JSON | `screens/admin/questions/` |
| US6 | Admin     | Tableau de bord : derniers résultats, recherche, filtre par année | `screens/admin/resultats_screen.dart` |
| US7 | Admin     | Camemberts de réussite par discipline et global par année | `screens/admin/statistiques_screen.dart` |

## Règles métier
- **Compte unique** : contrainte `UNIQUE (nom, email)` sur `candidats`.
  Le nom est enregistré en majuscules et l'email en minuscules, pour que
  « Dupont » et « DUPONT » soient le même compte.
- **Un seul passage par test** : contrainte `UNIQUE (candidat_id, discipline)`
  sur `resultats`. La tentative est enregistrée **dès le début du test**
  (score 0) puis le score est mis à jour après chaque question. Quitter le
  test, fermer l'appli ou éteindre le téléphone ne permet donc pas de le
  recommencer : les questions non répondues comptent comme fausses.
- **Temps limite** : chaque question a son propre chrono (5 à 600 s).
  Temps écoulé = question fausse, on passe à la suivante.
- **Correction** : une réponse est juste si toutes les bonnes options, et
  seulement elles, sont cochées.
- **Réussite** : un test est réussi à partir de **50 %** de bonnes réponses
  (`DatabaseService.seuilReussite`).
- **Année scolaire** : de septembre à août (ex. `2026-2027`), fixée à
  l'inscription du candidat ; elle sert aux filtres US6 et US7.
- **Import JSON** (US5) : remplace toute une discipline dans une
  transaction (tout ou rien). Format : `docs/exemple_questions.json`.
- **Questions de départ** : 5 questions par discipline sont insérées au
  premier lancement pour qu'un candidat puisse passer un test tout de suite.

## Base de données
`lib/services/database_service.dart` – schéma version 2 :
`candidats`, `questions`, `resultats`, `admins`.
Une base créée par la version 1 est migrée automatiquement (mot de passe
admin haché, questions de départ ajoutées dans les disciplines vides) sans
perdre les candidats ni les résultats.

## Équipe
- Dosseh APETI (Scrum Master) – US1, US5
- Reda – base SQLite, US4
- Ichan – US2, US3
- Ariela – US6, US7

## Organisation
- Une branche par user story : `feature/usX-...`, relue par un coéquipier
- Commits : `feat(USx):`, `fix(USx):`, `test:`, `docs:`
