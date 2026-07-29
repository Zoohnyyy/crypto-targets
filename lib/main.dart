import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'providers/theme_provider.dart';
import 'services/backend_sync.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'ui/main_shell.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background isolate + periodic refresh (widget + alerts every ~15 min).
  await BackgroundService.initialise();
  await BackgroundService.registerPeriodicRefresh();

  // Local notifications for price alerts.
  await NotificationService.instance.init();

  // Push (instant alerts from the backend). Inert unless a backend URL is set.
  // The token feeds BackendSync so the backend knows where to push.
  PushService.instance.onToken((token) {
    BackendSync.instance.fcmToken = token;
  });
  await PushService.instance.init();

  runApp(const CryptoApp());
}

class CryptoApp extends StatelessWidget {
  const CryptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'Crypto Targets',
          debugShowCheckedModeBanner: false,
          themeMode: theme.mode,
          theme: AppTheme.build(Brightness.light),
          darkTheme: AppTheme.build(Brightness.dark),
          home: const MainShell(),
        ),
      ),
    );
  }
}
