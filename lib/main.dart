import 'package:material_ui/material_ui.dart';

import 'state/app_state.dart';
import 'state/storage.dart';
import 'ui/app_scope.dart';
import 'ui/home_page.dart';
import 'ui/remote_pages.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(configStore: PrefsConfigStore(), secretStore: SecureSecretStore());
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
        theme: molaplanTheme(),
        darkTheme: molaplanTheme(),
        themeMode: ThemeMode.dark,
        home: const HomePage(),
      ),
    );
  }
}
