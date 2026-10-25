import 'package:flutter_test/flutter_test.dart';
import 'package:flauncher/models/category.dart';

void main() {
  test('Benchmark _findTargetCategoryForNewApp optimization', () {
    int numCategories = 100;
    Map<int, Category> _categoriesById = {};

    for (int i = 0; i < numCategories; i++) {
      _categoriesById[i] = Category(
        id: i,
        name: i == numCategories - 2 ? "TV Apps" : (i == numCategories - 1 ? "Non-TV Apps" : "Cat $i"),
        type: CategoryType.grid,
        sort: CategorySort.manual,
        columnsCount: 4,
        rowHeight: 100,
        order: i,
      );
    }

    Map<String, Category>? _categoriesByNameCache;
    Category? _fallbackCategoryCache;

    void _invalidateCategoryCache() {
      _categoriesByNameCache = null;
      _fallbackCategoryCache = null;
    }

    Category? _findTargetCategoryForNewAppOptimized(bool isSideloaded) {
      if (_categoriesById.isEmpty) return null;

      if (_categoriesByNameCache == null) {
        _categoriesByNameCache = {};
        for (var c in _categoriesById.values) {
          _categoriesByNameCache!.putIfAbsent(c.name.toLowerCase(), () => c);
        }

        try {
          _fallbackCategoryCache = _categoriesById.values.firstWhere(
            (c) => c.name.toLowerCase() != 'favorites',
            orElse: () => _categoriesById.values.first,
          );
        } catch (_) {
          _fallbackCategoryCache = null;
        }
      }

      final targetName = isSideloaded ? "non-tv apps" : "tv apps";
      return _categoriesByNameCache![targetName] ?? _fallbackCategoryCache;
    }

    // Measure Optimized
    Stopwatch sw = Stopwatch()..start();
    for (int i = 0; i < 100000; i++) {
      _findTargetCategoryForNewAppOptimized(false);
      _findTargetCategoryForNewAppOptimized(true);
    }
    sw.stop();
    print("Optimized time: " + sw.elapsedMilliseconds.toString() + " ms");
  });
}
