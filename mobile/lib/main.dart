import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'utils/theme_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicijalizuj auth service singleton i provjeri da li je korisnik već prijavljen
  final authService = AuthService.instance;
  await authService.initialize();

  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;

  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SApplauz',
      theme: ThemeHelper.lightTheme,
      home: authService.isAuthenticated
          ? const HomeScreen()
          : const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

