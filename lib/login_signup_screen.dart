import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart'; // 👈 New screen import

class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLogin = true;
  bool loading = false;
  bool hidePassword = true;

  void toggleFormType() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  Future<void> handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage("Please fill all fields");
      return;
    }

    try {
      setState(() => loading = true);

      if (isLogin) {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BingoHomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? "Authentication error");
    } finally {
      setState(() => loading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF7B1FA2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00695C), Color(0xFF7B1FA2), Color(0xFFFF8F00)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/bingo.png', width: 80, height: 80),
                    const SizedBox(height: 16),
                    Text(
                      isLogin ? "Welcome Back!" : "Join Bingo Mania!",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7B1FA2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(Icons.email, color: Color(0xFF7B1FA2)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF8F00), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock, color: Color(0xFF7B1FA2)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            hidePassword ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF7B1FA2),
                          ),
                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFFF8F00), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                            );
                          },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: Color(0xFF7B1FA2),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 10),
                    loading
                        ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8F00)),
                    )
                        : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFFF8F00),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        onPressed: handleAuth,
                        child: Text(
                          isLogin ? "Login" : "Sign Up",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: toggleFormType,
                      child: Text(
                        isLogin
                            ? "Don't have an account? Sign Up"
                            : "Already have an account? Login",
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF7B1FA2),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
