import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/database_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = await DatabaseHelper.instance.loginUser(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    setState(() {
      _isLoading = false;
    });

    if (user != null) {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: user,
        );
      }
    } else {
      setState(() {
        _errorMessage = 'E-posta veya şifre hatalı. Lütfen kontrol edin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAF6F0),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -120,
              top: -120,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4A7C59).withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              right: -120,
              bottom: -120,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF705C30).withOpacity(0.08),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Icon/Logo
                      Hero(
                        tag: 'logo',
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF4A7C59),
                          child: Icon(
                            Icons.agriculture,
                            size: 44,
                            color: const Color(0xFFFAF6F0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tarla Gözcüsü',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.literata(
                          textStyle: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4A7C59),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'AI Destekli Karar Destek Sistemi',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunitoSans(
                          textStyle: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF6B6358),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Card containing form
                      Card(
                        color: Colors.white.withOpacity(0.85),
                        elevation: 4,
                        shadowColor: Colors.black12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                          side: BorderSide(
                            color: const Color(0xFF4A7C59).withOpacity(0.1),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Giriş Yap',
                                  style: GoogleFonts.literata(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2E3230),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFDAD8),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFB83230).withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.nunitoSans(
                                        color: const Color(0xFF690005),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'E-posta Adresi',
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF4A7C59), width: 2),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'E-posta giriniz';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Geçerli bir e-posta giriniz';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText: 'Şifre',
                                    prefixIcon: const Icon(Icons.lock_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF4A7C59), width: 2),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Şifre giriniz';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A7C59)),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: _login,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF4A7C59),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          elevation: 2,
                                        ),
                                        child: Text(
                                          'Giriş Yap',
                                          style: GoogleFonts.nunitoSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hesabınız yok mu? ',
                            style: GoogleFonts.nunitoSans(
                              color: const Color(0xFF6B6358),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: Text(
                              'Yeni Kayıt Oluştur',
                              style: GoogleFonts.nunitoSans(
                                color: const Color(0xFF4A7C59),
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
