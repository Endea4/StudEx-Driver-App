import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/nav.dart';
import 'core/storage/local_storage.dart';
import 'core/theme.dart';
import 'providers/app_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/history_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/rating_provider.dart';
import 'providers/reputation_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/ride_provider.dart';
import 'services/chat_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/debt/debt_list_screen.dart';
import 'screens/rating/pending_ratings_screen.dart';
import 'screens/reputation/reputation_screen.dart';
import 'screens/profile/profile_edit_screen.dart';
import 'screens/settings/change_password_screen.dart';
import 'screens/trip/trip_detail_screen.dart';
import 'screens/ride/ride_screen.dart';

// navigatorKey now lives in core/nav.dart so providers can navigate without
// importing main.dart (which would be a circular import).
final ValueNotifier<Map<String, String>?> testLoginNotifier = ValueNotifier(null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppTheme.surface,
  ));

  final prefs = await SharedPreferences.getInstance();
  final localStorage = LocalStorage(prefs);

  await NotificationService.instance.init();
  await PushService.instance.init();

  final appProvider = AppProvider(localStorage: localStorage);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider(
          create: (_) => DriverProvider(appProvider.authService, appProvider.apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(appProvider.historyService, appProvider.wsClient),
        ),
        ChangeNotifierProvider(
          create: (_) => DebtProvider(appProvider.debtService),
        ),
        ChangeNotifierProvider(
          create: (_) => RatingProvider(appProvider.ratingService),
        ),
        ChangeNotifierProvider(
          create: (_) => ReputationProvider(appProvider.reputationService),
        ),
        ChangeNotifierProvider(
          create: (_) => RideProvider(appProvider.apiClient, appProvider.wsClient, appProvider.localStorage),
        ),
        ChangeNotifierProvider(
          create: (_) => ChatProvider(
            ChatService(appProvider.apiClient),
            appProvider.wsClient,
          ),
        ),
      ],
      child: const StudExApp(),
    ),
  );

  const channel = MethodChannel('studex/test');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'navigate') {
      final route = call.arguments['route'] as String?;
      if (route != null) {
        navigatorKey.currentState?.pushNamed('/$route');
      }
    }
  });

  // E2E test hook: if the app was launched via the TEST_LOGIN intent, pull the
  // credentials from the native side and feed the sign-in screen.
  try {
    final pending = await channel.invokeMethod('getPendingLogin');
    if (pending is Map) {
      final phone = pending['phone']?.toString() ?? '';
      final password = pending['password']?.toString() ?? '';
      if (phone.isNotEmpty && password.isNotEmpty) {
        testLoginNotifier.value = {'phone': phone, 'password': password};
      }
    }
  } catch (_) {}
}

class StudExApp extends StatelessWidget {
  const StudExApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudEx Driver',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      home: const SplashScreen(),
      routes: {
        '/sign-in': (_) => const SignInScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/history': (_) => const HistoryScreen(),
        '/debts': (_) => const DebtListScreen(),
        '/ratings': (_) => const PendingRatingsScreen(),
        '/reputation': (_) => const ReputationScreen(),
        '/profile': (_) => const ProfileEditScreen(),
        '/change-password': (_) => const ChangePasswordScreen(),
        '/ride': (_) => const RideScreen(),
        '/chat': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments as Map<String, dynamic>;
          return ChatScreen(
            tripId: args['tripId'] as String,
            driverRefId: (args['driverRefId'] as String?) ?? '',
            customerRefId: (args['customerRefId'] as String?) ?? '',
            orderId: (args['orderId'] as String?) ?? '',
            history: (args['history'] as bool?) ?? false,
          );
        },
        '/trip': (ctx) {
          final tripId = ModalRoute.of(ctx)!.settings.arguments as String;
          return TripDetailScreen(tripId: tripId);
        },
      },
    );
  }
}
