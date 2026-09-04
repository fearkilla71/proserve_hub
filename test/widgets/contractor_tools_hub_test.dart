import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proserve_hub/l10n/app_localizations.dart';
import 'package:proserve_hub/widgets/contractor_tools_hub.dart';

void main() {
  Widget wrap({required Locale locale}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ContractorToolsHub(
          userData: const {
            'subscriptionTier': 'enterprise',
            'leadCredits': 3,
            'exclusiveLeadCredits': 2,
            'stripePayoutsEnabled': true,
          },
          openSubscription: () {},
          openProToolOrSubscribe: ({required open}) => open(),
          openEnterpriseToolOrSubscribe: ({required open}) => open(),
        ),
      ),
    );
  }

  testWidgets('renders grouped contractor tools in English', (tester) async {
    await tester.pumpWidget(wrap(locale: const Locale('en')));

    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Win Work'), findsNothing);
    expect(find.text('AI Bid Analyzer'), findsNothing);
    await tester.scrollUntilVisible(find.text('Estimate & Quote'), 500);
    expect(find.text('Estimate & Quote'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('AI Invoice Maker'), 500);
    expect(find.text('AI Invoice Maker'), findsOneWidget);
  });

  testWidgets('renders grouped contractor tools in Spanish', (tester) async {
    await tester.pumpWidget(wrap(locale: const Locale('es')));

    expect(find.text('Herramientas'), findsOneWidget);
    expect(find.text('Hoy'), findsOneWidget);
    expect(find.text('Ganar trabajos'), findsNothing);
    expect(find.text('Analizador de cotizaciones con IA'), findsNothing);
    await tester.scrollUntilVisible(find.text('Presupuestar y cotizar'), 500);
    expect(find.text('Presupuestar y cotizar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Creador de facturas con IA'),
      500,
    );
    expect(find.text('Creador de facturas con IA'), findsOneWidget);
  });
}
