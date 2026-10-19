import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naazza/features/meal_analysis/data/ingredient_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> response() => {
    'status': 'ingredients',
    'hasMore': false,
    'rows': [
      {'company': '새 업체', 'ingredientText': '대두,밀'},
    ],
  };
  test(
    'same product same day cached across app cache instances; next day refreshed; accounts separated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var at = DateTime(2026, 10, 15, 8), calls = 0;
      Future<Map<String, dynamic>> fetch(String report, String company) async {
        calls++;
        return response();
      }

      final cache = IngredientCache(prefs, fetch, now: () => at);
      await cache.get('user', '123456', '구 업체');
      final second = await IngredientCache(
        prefs,
        fetch,
        now: () => at,
      ).get('user', '123456', '새 업체');
      expect(calls, 1);
      expect(second['fromCache'], true);
      expect(second['companyVerified'], true);
      await cache.get('other', '123456', '새 업체');
      expect(calls, 2);
      at = at.add(const Duration(days: 1));
      await cache.get('user', '123456', '새 업체');
      expect(calls, 3);
    },
  );
  test(
    '7 day expiry and count cap remove old entries rather than accumulating',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var at = DateTime(2026, 10, 1);
      final cache = IngredientCache(
        prefs,
        (a, b) async => response(),
        now: () => at,
        maxEntries: 2,
      );
      await cache.get('user', '123456', '');
      at = at.add(const Duration(days: 1));
      await cache.get('user', '123457', '');
      at = at.add(const Duration(days: 1));
      await cache.get('user', '123458', '');
      expect(
        (jsonDecode(prefs.getString(IngredientCache.storageKey)!) as Map)
            .length,
        2,
      );
      at = DateTime(2026, 10, 10);
      await cache.prune();
      expect(jsonDecode(prefs.getString(IngredientCache.storageKey)!), isEmpty);
    },
  );
  test(
    'concurrent requests coalesced; errors not cached so user can retry',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final pending = Completer<Map<String, dynamic>>();
      final cache = IngredientCache(prefs, (a, b) {
        calls++;
        return pending.future;
      });
      final one = cache.get('user', '123456', ''),
          two = cache.get('user', '123456', '');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(calls, 1);
      pending.complete(response());
      await Future.wait([one, two]);
      final failed = IngredientCache(prefs, (a, b) async {
        calls++;
        return {'status': 'unavailable'};
      });
      await failed.get('user', '999999', '');
      await failed.get('user', '999999', '');
      expect(calls, 3);
    },
  );
}
