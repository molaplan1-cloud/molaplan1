import 'package:material_ui/material_ui.dart';

import 'state/app_state.dart';
import 'state/storage.dart';
import 'ui/app_scope.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(configStore: PrefsConfigStore(), secretStore: SecureSecretStore());
  await state.load();
  runApp(MolaplanApp(state: state));
}

class MolaplanApp extends StatelessWidget {
  const MolaplanApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Molaplan',
        debugShowCheckedModeBanner: false,
        theme: molaplanTheme(),
        darkTheme: molaplanTheme(),
        themeMode: ThemeMode.dark,
        home: const HomePage(),
      ),
    );
  }
}
