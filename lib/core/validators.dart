/// Validates player names and game configuration.
class Validators {
  Validators._();

  /// Returns an error message if invalid, null if valid.
  static String? validatePlayerName(String name, {int maxLength = 20}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Name cannot be empty';
    if (trimmed.length > maxLength) {
      return 'Name must be $maxLength characters or fewer';
    }
    return null;
  }

  /// Returns true if enough players to start a game.
  static bool hasEnoughPlayers(int playerCount, {int minimum = 3}) {
    return playerCount >= minimum;
  }

  /// Returns true if impostor count is valid for given player count.
  static bool isValidImpostorCount(int impostorCount, int playerCount) {
    return impostorCount >= 1 && impostorCount < playerCount;
  }

  /// Ensures a name is unique within a list by appending a suffix.
  static String makeUnique(String name, List<String> existingNames) {
    var candidate = name.trim();
    if (!existingNames.contains(candidate)) return candidate;
    var counter = 2;
    while (existingNames.contains('$candidate $counter')) {
      counter++;
    }
    return '$candidate $counter';
  }
}
