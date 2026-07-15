import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'services/settings_store.dart';
import 'ui/app_state.dart';
import 'ui/home_page.dart';
import 'ui/pair_dialog.dart';

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
          theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
          home: const HomePage(),
        ),
      );
}
