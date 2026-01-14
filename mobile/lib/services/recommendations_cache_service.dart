import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recommendation.dart';

/// Servis za keširanje preporuka
class RecommendationsCacheService {
  static const String _cacheKey = 'recommendations_cache';
  static const String _cacheTimestampKey = 'recommendations_cache_timestamp';
  static const Duration _defaultTTL = Duration(hours: 1); // 1 sat default TTL

  /// Vraća TTL iz konfiguracije (može se proširiti da čita iz config file-a)
  static Duration get ttl => _defaultTTL;

  /// Sačuva preporuke u lokalni cache koristeći SharedPreferences.
  /// Također sačuva timestamp za provjeru validnosti cache-a.
  /// 
  /// [recommendations] - Lista preporuka koje se keširaju
  static Future<void> saveRecommendations(List<Recommendation> recommendations) async {
    final prefs = await SharedPreferences.getInstance();
    final recommendationsJson = recommendations.map((r) => r.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(recommendationsJson));
    await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());
  }

  /// Učitava preporuke iz cache-a ako su validne (nije stariji od TTL-a).
  /// Ako je cache stario ili ne postoji, vraća null.
  /// 
  /// Returns:
  /// - Lista preporuka ako je cache validan
  /// - null ako cache ne postoji ili je stario
  static Future<List<Recommendation>?> getCachedRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = prefs.getString(_cacheKey);
    final timestampStr = prefs.getString(_cacheTimestampKey);

    if (cacheData == null || timestampStr == null) {
      return null;
    }

    try {
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      
      // Provjeri da li je cache stario
      if (now.difference(timestamp) > ttl) {
        // Cache je stario, ali ga možemo vratiti za cold start
        return null;
      }

      // Cache je validan, parsiraj podatke
      final recommendationsJson = jsonDecode(cacheData) as List<dynamic>;
      final recommendations = recommendationsJson
          .map((json) => Recommendation.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return recommendations;
    } catch (e) {
      // Greška pri parsiranju, obriši cache
      await clearCache();
      return null;
    }
  }

  /// Provjerava da li cache postoji i nije stario (nije prošao TTL).
  /// 
  /// Returns:
  /// - true ako je cache validan
  /// - false ako cache ne postoji ili je stario
  static Future<bool> isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampStr = prefs.getString(_cacheTimestampKey);

    if (timestampStr == null) {
      return false;
    }

    try {
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      return now.difference(timestamp) <= ttl;
    } catch (e) {
      return false;
    }
  }

  /// Provjerava da li cache postoji (čak i ako je stario)
  static Future<bool> hasCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_cacheKey);
  }

  /// Vraća stari cache (za cold start)
  static Future<List<Recommendation>?> getStaleCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = prefs.getString(_cacheKey);

    if (cacheData == null) {
      return null;
    }

    try {
      final recommendationsJson = jsonDecode(cacheData) as List<dynamic>;
      final recommendations = recommendationsJson
          .map((json) => Recommendation.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return recommendations;
    } catch (e) {
      return null;
    }
  }

  /// Briše cache
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
  }

  /// Invalidira cache preporuka.
  /// Poziva se nakon kupovine karte ili ostavljene recenzije
  /// kako bi se osiguralo da se preporuke osvježe sa novim podacima.
  static Future<void> invalidateCache() async {
    await clearCache();
  }
}
