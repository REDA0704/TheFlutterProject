/// Calcule l'année scolaire d'une date.
///
/// L'année scolaire commence en septembre :
/// - 15/10/2025 -> "2025-2026"
/// - 20/03/2026 -> "2025-2026"
/// - 01/09/2026 -> "2026-2027"
String anneeScolaire(DateTime date) {
  final debut = date.month >= 9 ? date.year : date.year - 1;
  return '$debut-${debut + 1}';
}

/// Année scolaire en cours (utilisée à l'inscription d'un candidat).
String anneeScolaireActuelle() => anneeScolaire(DateTime.now());
