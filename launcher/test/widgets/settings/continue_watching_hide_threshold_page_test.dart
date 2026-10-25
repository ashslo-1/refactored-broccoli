import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/continue_watching_hide_threshold_page.dart';
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
          body: ContinueWatchingHideThresholdPage(),
        ),
      ),
    );
  }

  testWidgets('renders all hide threshold options and defaults to Off', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Hide Nearly Finished'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('90%'), findsOneWidget);
    expect(find.text('95%'), findsOneWidget);

    expect(settingsService.continueWatchingHideThreshold, 0);
  });

  testWidgets('selecting 90% updates setting to 90', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('90%'));
    await tester.pumpAndSettle();

    expect(settingsService.continueWatchingHideThreshold, 90);
  });

  testWidgets('selecting 95% updates setting to 95', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('95%'));
    await tester.pumpAndSettle();

    expect(settingsService.continueWatchingHideThreshold, 95);
  });

  testWidgets('selecting Off updates setting back to 0', (WidgetTester tester) async {
    await settingsService.setContinueWatchingHideThreshold(90);

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();

    expect(settingsService.continueWatchingHideThreshold, 0);
  });
}
