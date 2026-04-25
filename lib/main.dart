import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/storage/local_storage.dart';
import 'providers/app_provider.dart';
import 'providers/driver_provider.dart';
import 'providers/history_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/rating_provider.dart';
import 'providers/reputation_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/debt/debt_list_screen.dart';
import 'screens/rating/pending_ratings_screen.dart';
import 'screens/reputation/reputation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  final prefs = await SharedPreferences.getInstance();
  final localStorage = LocalStorage(prefs);
  final appProvider = AppProvider(localStorage: localStorage);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider(create: (_) => DriverProvider(appProvider.authService)),
        ChangeNotifierProvider(create: (_) => HistoryProvider(appProvider.historyService)),
        ChangeNotifierProvider(create: (_) => DebtProvider(appProvider.debtService)),
        ChangeNotifierProvider(create: (_) => RatingProvider(appProvider.ratingService)),
        ChangeNotifierProvider(create: (_) => ReputationProvider(appProvider.reputationService)),
      ],
      child: const StudExApp(),
    ),
  );
}

class StudExApp extends StatelessWidget {
  const StudExApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudEx Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: context.read<AppProvider>().isAuthenticated ? '/dashboard' : '/sign-in',
      routes: {
        '/sign-in': (_) => const SignInScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/history': (_) => const HistoryScreen(),
        '/debts': (_) => const DebtListScreen(),
        '/ratings': (_) => const PendingRatingsScreen(),
        '/reputation': (_) => const ReputationScreen(),
      },
    );
  }
}
