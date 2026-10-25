import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/apps_grid.dart';
import 'package:flauncher/widgets/category_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import '../mocks.mocks.dart';

Widget _buildTestWidget(Widget child, SettingsService settingsService) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChangeNotifierProvider<SettingsService>.value(
        value: settingsService,
        child: child,
      ),
    ),
  );
}

void main() {
  late MockSettingsService settingsService;
  late Category testCategory;

  setUp(() {
    settingsService = MockSettingsService();
    testCategory = Category(
      id: 1,
      name: 'TV Apps',
      sort: CategorySort.manual,
      type: CategoryType.row,
      rowHeight: 110,
      columnsCount: 6,
      order: 0,
    );
  });

  group('CategoryRow app count display', () {
    testWidgets('hides app count when showCategoryAppCount is false',
        (tester) async {
      when(settingsService.showCategoryTitles).thenReturn(true);
      when(settingsService.showCategoryAppCount).thenReturn(false);

      await tester.pumpWidget(
        _buildTestWidget(
          CategoryRow(
            category: testCategory,
            applications: const [],
          ),
          settingsService,
        ),
      );

      expect(find.text('TV Apps'), findsOneWidget);
      expect(find.text('•  0'), findsNothing);
    });

    testWidgets('shows app count when showCategoryAppCount is true',
        (tester) async {
      when(settingsService.showCategoryTitles).thenReturn(true);
      when(settingsService.showCategoryAppCount).thenReturn(true);

      await tester.pumpWidget(
        _buildTestWidget(
          CategoryRow(
            category: testCategory,
            applications: const [],
          ),
          settingsService,
        ),
      );

      expect(find.text('TV Apps'), findsOneWidget);
      expect(find.text('•  0'), findsOneWidget);
    });
  });

  group('AppsGrid app count display', () {
    testWidgets('hides app count when showCategoryAppCount is false',
        (tester) async {
      when(settingsService.showCategoryTitles).thenReturn(true);
      when(settingsService.showCategoryAppCount).thenReturn(false);

      await tester.pumpWidget(
        _buildTestWidget(
          AppsGrid(
            category: testCategory,
            applications: const [],
          ),
          settingsService,
        ),
      );

      expect(find.text('TV Apps'), findsOneWidget);
      expect(find.text('•  0'), findsNothing);
    });

    testWidgets('shows app count when showCategoryAppCount is true',
        (tester) async {
      when(settingsService.showCategoryTitles).thenReturn(true);
      when(settingsService.showCategoryAppCount).thenReturn(true);

      await tester.pumpWidget(
        _buildTestWidget(
          AppsGrid(
            category: testCategory,
            applications: const [],
          ),
          settingsService,
        ),
      );

      expect(find.text('TV Apps'), findsOneWidget);
      expect(find.text('•  0'), findsOneWidget);
    });
  });
}
