import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef IngredientFetcher =
    Future<Map<String, dynamic>> Function(String report, String company);

class IngredientCache {
  IngredientCache(
    this.preferences,
    this.fetcher, {
    DateTime Function()? now,
    this.maxEntries = 100,
  }) : now = now ?? DateTime.now;
  final SharedPreferences preferences;
  final IngredientFetcher fetcher;
  final DateTime Function() now;
  final int maxEntries;
  static const storageKey = 'naazza.ingredients.v1';
  final Map<String, Future<Map<String, dynamic>>> _pending = {};
  Map<String, dynamic> _entries() {
    try {
      return Map<String, dynamic>.from(
        jsonDecode(preferences.getString(storageKey) ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> prune() async {
    final entries = _entries();
    _prune(entries);
    await preferences.setString(storageKey, jsonEncode(entries));
  }

  void _prune(Map<String, dynamic> entries) {
    final cutoff =
        now().millisecondsSinceEpoch - const Duration(days: 7).inMilliseconds;
    entries.removeWhere(
      (key, value) =>
          value is! Map || value['at'] is! int || value['at'] <= cutoff,
    );
    final ordered = entries.keys.toList()
      ..sort(
        (a, b) => (entries[a]['at'] as int).compareTo(entries[b]['at'] as int),
      );
    while (entries.length > maxEntries) {
      entries.remove(ordered.removeAt(0));
    }
    // Bound persistent size even if the upstream returns unexpectedly large lists.
    while (entries.isNotEmpty &&
        utf8.encode(jsonEncode(entries)).length > 2 * 1024 * 1024) {
      entries.remove(ordered.removeAt(0));
    }
  }

  Map<String, dynamic> _view(
    Map<String, dynamic> data,
    String company,
    bool cached,
    int at,
  ) {
    final rows = (data['rows'] as List? ?? []).whereType<Map>();
    final expected = company.replaceAll(RegExp(r'\s'), '');
    return {
      ...data,
      'fromCache': cached,
      'cachedAt': at,
      'companyVerified':
          expected.isNotEmpty &&
          rows.isNotEmpty &&
          rows.every(
            (r) =>
                (r['company']?.toString() ?? '').replaceAll(
                  RegExp(r'\s'),
                  '',
                ) ==
                expected,
          ),
    };
  }

  Future<Map<String, dynamic>> get(
    String user,
    String report,
    String company,
  ) async {
    if (user.isEmpty || !RegExp(r'^\d{5,30}$').hasMatch(report)) {
      throw ArgumentError('제품 식별 정보가 필요해요.');
    }
    final date = now();
    final day = '${date.year}-${date.month}-${date.day}';
    final key = jsonEncode([user, report, day]);
    final entries = _entries();
    _prune(entries);
    await preferences.setString(storageKey, jsonEncode(entries));
    final cached = entries[key];
    if (cached is Map && cached['data'] is Map) {
      return _view(
        Map<String, dynamic>.from(cached['data'] as Map),
        company,
        true,
        cached['at'] as int,
      );
    }
    final existing = _pending[key];
    if (existing != null) {
      final result = await existing;
      return _view(result, company, true, result['cachedAt'] as int);
    }
    final request = _fetch(key, report, company);
    _pending[key] = request;
    try {
      return _view(await request, company, false, now().millisecondsSinceEpoch);
    } finally {
      _pending.remove(key);
    }
  }

  Future<Map<String, dynamic>> _fetch(
    String key,
    String report,
    String company,
  ) async {
    final data = await fetcher(
      report,
      company,
    ).timeout(const Duration(seconds: 8));
    final at = now().millisecondsSinceEpoch;
    if (data['status'] == 'ingredients' && data['hasMore'] == false) {
      final entries = _entries();
      entries[key] = {'at': at, 'data': data};
      _prune(entries);
      await preferences.setString(storageKey, jsonEncode(entries));
    }
    return {...data, 'cachedAt': at};
  }
}

Future<IngredientCache>? _cacheFuture;
Future<IngredientCache> _cache() => _cacheFuture ??= _createCache();
Future<IngredientCache> _createCache() async {
  final preferences = await SharedPreferences.getInstance();
  return IngredientCache(preferences, (report, company) async {
    final response = await Supabase.instance.client.functions.invoke(
      'product-ingredients',
      body: {'reportNumber': report, 'company': company, 'page': 1},
    );
    return Map<String, dynamic>.from(response.data as Map);
  });
}

Future<void> cleanupIngredientCache() async => (await _cache()).prune();
Future<Map<String, dynamic>> cachedIngredients(
  String report,
  String company,
) async {
  final user = Supabase.instance.client.auth.currentUser?.id;
  if (user == null) throw StateError('로그인이 필요해요.');
  return (await _cache()).get(user, report, company);
}
