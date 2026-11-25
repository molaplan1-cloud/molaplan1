import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';

import 'state/app_state.dart';
import 'state/storage.dart';
import 'ui/app_scope.dart';
import 'ui/home_page.dart';
import 'ui/remote_pages.dart';
import 'ui/theme.dart';
import 'l10n/gen/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(
    configStore: PrefsConfigStore(),
    secretStore: SecureSecretStore(),
    energyStore: PrefsConfigStore('molaplan.energy.v1'),
  );
  state.account.autoSync = true; // background sync when signed in
  await state.load();
  if (state.config.bridgeMode) await keepScreenOn(true);
  state.update.autoCheck = true;
  runApp(MolaplanApp(state: state));
}

final navigatorKey = GlobalKey<NavigatorState>();

class MolaplanApp extends StatelessWidget {
  const MolaplanApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    // The bridge asks here when a phone pairs with the typed code.
    state.remote.approver = (name) async {
      final c = navigatorKey.currentContext;
      return c != null && c.mounted ? askApproval(c, name) : false;
    };
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Molaplan',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: molaplanTheme(brightness: Brightness.light),
        darkTheme: molaplanTheme(),
        themeMode: ThemeMode.dark,
        locale: Locale(state.lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const HomePage(),
      ),
    );
  }
}
