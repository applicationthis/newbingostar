import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void sendResetEmail() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage("Please enter your email");
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      showMessage("Password reset link sent to $email");
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? "Failed to send reset email");
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.teal,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reset Password"),
        backgroundColor: const Color(0xFF7B1FA2),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text(
              "Enter your email to receive password reset link",
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Email",
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: sendResetEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Send Reset Link",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }
}
