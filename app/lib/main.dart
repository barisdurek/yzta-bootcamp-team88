import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TarlaGozcusuApp());
}

class TarlaGozcusuApp extends StatelessWidget {
  const TarlaGozcusuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tarla Gözcüsü',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A7C59),
          primary: const Color(0xFF4A7C59),
          secondary: const Color(0xFF6B6358),
          tertiary: const Color(0xFF705C30),
          background: const Color(0xFFFAF6F0),
          surface: const Color(0xFFFAF6F0),
          error: const Color(0xFFB83230),
        ),
        textTheme: GoogleFonts.nunitoSansTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF0ECE4),
          foregroundColor: Color(0xFF4A7C59),
          elevation: 1,
        ),
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        if (settings.name == '/dashboard') {
          final user = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => DashboardScreen(user: user),
          );
        }
        return null;
      },
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}
