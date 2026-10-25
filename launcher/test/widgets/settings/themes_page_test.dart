import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/themes_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

void main() {
  late SettingsService settingsService;
  late SharedPreferences sharedPreferences;

  setUp(() async {
    SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.empty();
    sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.clear();
    settingsService = SettingsService(sharedPreferences);
  });

  Widget buildSubject() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChangeNotifierProvider<SettingsService>.value(
        value: settingsService,
        child: const Scaffold(
          body: ThemesPage(),
        ),
      ),
    );
  }

  testWidgets('renders all 7 theme options', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Glow'), findsOneWidget);
    expect(find.text('Squircle'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Minimal'), findsOneWidget);
    expect(find.text('Capsule'), findsOneWidget);
  });

  testWidgets('selecting Glow updates theme to glow', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Glow'));
    await tester.pumpAndSettle();

    expect(settingsService.themes, 'glow');
  });

  testWidgets('selecting Squircle updates theme to squircle', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Squircle'));
    await tester.pumpAndSettle();

    expect(settingsService.themes, 'squircle');
  });

  testWidgets('selecting Minimal updates theme to minimal', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Minimal'), 100);
    await tester.tap(find.text('Minimal'));
    await tester.pumpAndSettle();

    expect(settingsService.themes, 'minimal');
  });

  testWidgets('selecting Classic updates theme to classic', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Classic'), 100);
    await tester.tap(find.text('Classic'));
    await tester.pumpAndSettle();

    expect(settingsService.themes, 'classic');
  });

  testWidgets('selecting Capsule updates theme to capsule', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Capsule'), 100);
    await tester.tap(find.text('Capsule'));
    await tester.pumpAndSettle();

    expect(settingsService.themes, 'capsule');
  });
}
