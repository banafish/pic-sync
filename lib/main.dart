import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'services/settings_store.dart';
import 'ui/app_state.dart';
import 'ui/home_page.dart';
import 'ui/pair_dialog.dart';
import 'ui/permission_gate.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  final store = SettingsStore(p.join(dir.path, 'settings.json'));
  final settings = await store.load();
  final appState = AppState(store: store, settings: settings);
  appState.pairApprover = (peerId, peerName) => showPairDialog(navigatorKey, peerName);
  unawaited(appState.startServices());
  runApp(PicSyncApp(appState: appState));
}

class PicSyncApp extends StatelessWidget {
  const PicSyncApp({super.key, required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: appState,
        child: MaterialApp(
          title: '图片同步',
          navigatorKey: navigatorKey,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF007A78),
              brightness: Brightness.light,
              primary: const Color(0xFF006A67),
              onPrimary: Colors.white,
              primaryContainer: const Color(0xFF70F7F2),
              onPrimaryContainer: const Color(0xFF00201F),
              secondary: const Color(0xFF4A6362),
              surfaceContainerLow: const Color(0xFFF7FBFB),
              surfaceContainer: const Color(0xFFEEF4F4),
              surfaceContainerHigh: const Color(0xFFE3EAE9),
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.grey.withAlpha(35),
                  width: 1,
                ),
              ),
              color: Colors.white,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Color(0xFFF7FBFB),
              titleTextStyle: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191C1C),
              ),
            ),
            scaffoldBackgroundColor: const Color(0xFFF7FBFB),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFEFF5F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF007A78),
              brightness: Brightness.dark,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withAlpha(20),
                  width: 1,
                ),
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          themeMode: ThemeMode.system,
          home: const PermissionGate(child: HomePage()),
        ),
      );
}
