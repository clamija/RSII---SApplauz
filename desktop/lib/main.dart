import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'utils/theme_helper.dart';

// Globalna instanca AuthService-a - koristi singleton
final AuthService globalAuthService = AuthService.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicijalizuj auth service i provjeri da li je korisnik već prijavljen
  await globalAuthService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SApplauz Desktop',
      theme: ThemeHelper.lightTheme,
      home: globalAuthService.isAuthenticated
          ? const HomeScreen()
          : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

