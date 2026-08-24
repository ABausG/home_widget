import 'package:home_widget_generator/home_widget_generator.dart';

/// Localized widget: translated body text plus a translated gallery entry.
///
/// `caption` is fixed at build time and costs no data field. `greeting` is a
/// data field, so the app can override any locale at runtime:
///
///   await LocalizedGreetingHomeWidget.saveData(
///     greeting: LocalizedGreetingHomeWidgetTranslations(
///       en: 'Hi there', de: 'Hallo du', ptBR: 'Oi',
///     ),
///   );
///
/// Values are pushed per locale, so the widget follows a language change on its
/// own rather than waiting for the app to run again.
@HomeWidget(
  name: 'Localized Greeting',
  description: 'Greets you in your language',
  localization: HomeWidgetLocalization(
    defaultLocale: 'en',
    supportedLocales: ['en', 'de', 'pt-BR'],
    // No 'en' key here — the base text is the top-level name/description.
    name: {'de': 'Lokalisierte Begrüßung', 'pt-BR': 'Saudação Localizada'},
    description: {
      'de': 'Begrüßt dich in deiner Sprache',
      'pt-BR': 'Cumprimenta você no seu idioma',
    },
  ),
  android: HomeWidgetAndroidConfiguration(),
  iOS: HomeWidgetIOSConfiguration(
    groupId: 'group.es.antonborri.generatorBasics',
    supportedFamilies: [HWWidgetFamily.systemSmall],
  ),
  widget: HWColumn(
    crossAxisAlignment: HWCrossAxisAlignment.start,
    children: [
      HWText.localized({
        'en': 'Greeting',
        'de': 'Begrüßung',
        'pt-BR': 'Saudação',
      }, style: HWRoleTextStyle(role: HWTextStyleRole.caption)),
      HWText(
        HWString.localized(
          'greeting',
          defaultTranslations: {'en': 'Hello', 'de': 'Hallo', 'pt-BR': 'Olá'},
        ),
        style: HWRoleTextStyle(
          role: HWTextStyleRole.title,
          fontWeight: HWFontWeight.bold,
        ),
      ),
    ],
  ),
)
class LocalizedGreeting {}
