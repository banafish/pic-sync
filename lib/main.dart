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
              seedColor: const Color(0xFF006A67),
              brightness: Brightness.light,
              primary: const Color(0xFF006A67),
              onPrimary: Colors.white,
              primaryContainer: const Color(0xFF9CF2EC),
              onPrimaryContainer: const Color(0xFF00201F),
              secondary: const Color(0xFF4A6362),
              surface: const Color(0xFFF4F8F8),
              surfaceContainerLow: const Color(0xFFF8FCFC),
              surfaceContainer: const Color(0xFFEDF3F3),
              surfaceContainerHigh: const Color(0xFFE2ECEC),
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F8F8),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFF006A67).withAlpha(18),
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
              backgroundColor: Color(0xFFF4F8F8),
              titleTextStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF161D1D),
                letterSpacing: -0.3,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFEFF5F4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 6,
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 3,
              backgroundColor: const Color(0xFF006A67),
              foregroundColor: Colors.white,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF006A67),
              brightness: Brightness.dark,
              surface: const Color(0xFF111414),
            ),
            scaffoldBackgroundColor: const Color(0xFF111414),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Colors.white.withAlpha(22),
                  width: 1,
                ),
              ),
              color: const Color(0xFF1C2121),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Color(0xFF111414),
              surfaceTintColor: Colors.transparent,
              titleTextStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE1E3E3),
                letterSpacing: -0.3,
              ),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 3,
            ),
          ),
          themeMode: ThemeMode.system,
          home: const PermissionGate(child: HomePage()),
        ),
      );
}
