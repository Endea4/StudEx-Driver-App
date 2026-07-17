import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/storage/local_storage.dart';
import 'core/theme.dart';
import 'providers/app_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/history_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/rating_provider.dart';
import 'providers/reputation_provider.dart';
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
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

  final appProvider = AppProvider(localStorage: localStorage);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider(
          create: (_) => DriverProvider(appProvider.authService, appProvider.apiClient),
        ),
        ChangeNotifierProvider(
          create: (_) => HistoryProvider(appProvider.historyService),
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
        '/trip': (ctx) {
          final tripId = ModalRoute.of(ctx)!.settings.arguments as String;
          return TripDetailScreen(tripId: tripId);
        },
      },
    );
  }
}
