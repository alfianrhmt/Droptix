import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan lokal untuk 5 pencarian terakhir.
class RecentSearchesStorage {
  RecentSearchesStorage([SharedPreferences? prefs]) : _prefsInstance = prefs;

  final SharedPreferences? _prefsInstance;
  static const String storageKey = 'droptix_recent_searches';
  static const int maxCount = 5;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  Future<List<String>> getSearches() async {
    final prefs = await _getPrefs();
    return prefs.getStringList(storageKey) ?? const <String>[];
  }

  Future<void> addSearch(String term) async {
    final clean = term.trim();
    if (clean.isEmpty) return;

    final prefs = await _getPrefs();
    final current =
        List<String>.from(prefs.getStringList(storageKey) ?? const []);
    current.removeWhere(
        (item) => item.trim().toLowerCase() == clean.toLowerCase());
    current.insert(0, clean);
    if (current.length > maxCount) {
      current.removeRange(maxCount, current.length);
    }
    await prefs.setStringList(storageKey, current);
  }

  Future<void> removeSearch(String term) async {
    final prefs = await _getPrefs();
    final current =
        List<String>.from(prefs.getStringList(storageKey) ?? const []);
    current.removeWhere(
        (item) => item.trim().toLowerCase() == term.trim().toLowerCase());
    await prefs.setStringList(storageKey, current);
  }

  Future<void> clearAll() async {
    final prefs = await _getPrefs();
    await prefs.remove(storageKey);
  }
}
