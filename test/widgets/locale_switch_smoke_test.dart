import 'package:clutterzen/services/i18n_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocaleSmokeApp extends StatelessWidget {
  const _LocaleSmokeApp();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: I18nService.localeListenable,
      builder: (context, locale, _) {
        return MaterialApp(
          locale: locale,
          supportedLocales: I18nService.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Column(
              children: [
                Text(I18nService.translate('sign_in')),
                Text(I18nService.translate('scan_history')),
                Text(I18nService.translate('settings')),
                ElevatedButton(
                  key: const Key('to_es'),
                  onPressed: () => I18nService.setLocale(
                    const Locale('es', 'ES'),
                  ),
                  child: const Text('es'),
                ),
                ElevatedButton(
                  key: const Key('to_en'),
                  onPressed: () => I18nService.setLocale(
                    const Locale('en', 'US'),
                  ),
                  child: const Text('en'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('locale switch updates representative UI strings',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await I18nService.initialize();

    await tester.pumpWidget(const _LocaleSmokeApp());
    await tester.pumpAndSettle();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Scan History'), findsOneWidget);

    await tester.tap(find.byKey(const Key('to_es')));
    await tester.pumpAndSettle();

    expect(I18nService.currentLocale.languageCode, 'es');
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Historial de escaneos'), findsOneWidget);
  });

  test('selected locale persists across re-initialize', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await I18nService.initialize();

    await I18nService.setLocale(const Locale('fr', 'FR'));
    expect(I18nService.currentLocale.languageCode, 'fr');

    await I18nService.initialize();
    expect(I18nService.currentLocale.languageCode, 'fr');
  });
}
