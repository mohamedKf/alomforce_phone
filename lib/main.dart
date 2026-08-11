// main.dart — AlomForce phone app. Login, then a home per staff role.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'api.dart';
import 'screens/login_screen.dart';
import 'screens/manager/manager_home.dart';
import 'screens/role_placeholder.dart';
import 'screens/warehouse/warehouse_home.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  appState.boot();
  runApp(const AlomForceApp());
}

class AlomForceApp extends StatelessWidget {
  const AlomForceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'AlomForce',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          // Language + direction: Hebrew/Arabic flip the whole app to RTL.
          locale: Locale(api.language),
          supportedLocales: const [Locale('en'), Locale('he'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: appState.booting
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : appState.loggedIn
                  ? homeForRole(appState.role)
                  : const LoginScreen(),
        );
      },
    );
  }
}

// Each role lands on its own home. Roles without a phone app yet get a clear
// placeholder rather than a wrong screen.
Widget homeForRole(String role) {
  switch (role) {
    // A driver is a stock worker who also delivers, so they share the worker
    // home (which adds a Deliveries tab for the driver role).
    case 'warehouse':
    case 'driver':
      return const WarehouseHome();
    case 'manager':
      return const ManagerHome();
    default:
      return RolePlaceholder(role: role);
  }
}
