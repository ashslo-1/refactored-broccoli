import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/settings/screensaver_animation_page.dart';
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
          body: ScreensaverAnimationPage(),
        ),
      ),
    );
  }

  testWidgets('renders all screensaver animation options', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('Screensaver Animation'), findsOneWidget);
    expect(find.text('DVD Bounce'), findsOneWidget);
    expect(find.text('Minimal Fade'), findsOneWidget);
    expect(find.text('Character Scatter'), findsOneWidget);
  });

  testWidgets('default animation is DVD Bounce and selecting Minimal Fade updates settings', (WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(settingsService.screensaverAnimationStyle, SCREENSAVER_ANIMATION_BOUNCE);

    await tester.tap(find.text('Minimal Fade'));
    await tester.pumpAndSettle();

    expect(settingsService.screensaverAnimationStyle, SCREENSAVER_ANIMATION_FADE);

    await tester.tap(find.text('Character Scatter'));
    await tester.pumpAndSettle();

    expect(settingsService.screensaverAnimationStyle, SCREENSAVER_ANIMATION_SCATTER);
  });
}
