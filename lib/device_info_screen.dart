import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

import 'dashboard_screen.dart'; // Import your home screen

class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({super.key});

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> with TickerProviderStateMixin {
  String? _deviceModel;
  String? _deviceId;
  String? _status;
  bool _isSuccess = false;
  bool _isLoading = true;

  late AnimationController _fadeController;
  late AnimationController _buttonController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize animation controllers
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _storeDeviceInfo();
  }

  Future<void> _storeDeviceInfo() async {
    try {
      // Step 1: Anonymous Login
      final userCred = await FirebaseAuth.instance.signInAnonymously();
      final uid = userCred.user?.uid ?? 'unknown';

      // Step 2: Device Info
      final deviceInfo = DeviceInfoPlugin();
      String model = '';
      String id = '';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        model = androidInfo.model ?? 'unknown';
        id = androidInfo.id ?? 'unknown';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        model = iosInfo.utsname.machine ?? 'unknown';
        id = iosInfo.identifierForVendor ?? 'unknown';
      }

      // Step 3: Save to Firestore
      await FirebaseFirestore.instance.collection('devices').doc(uid).set({
        'model': model,
        'device_id': id,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Step 4: Update UI
      setState(() {
        _deviceModel = model;
        _deviceId = id;
        _status = '✅ Device info stored successfully';
        _isSuccess = true;
        _isLoading = false;
      });
      _fadeController.forward(); // Start fade animation
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
        _isSuccess = false;
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  void _goToHomeScreen() {
    _buttonController.forward().then((_) {
      _buttonController.reverse();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Info'),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF00695C), // Teal
              Color(0xFF7B1FA2), // Deep Purple
              Color(0xFFFF8F00), // Amber
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Loading indicator
                if (_isLoading)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C4B4)),
                  ),
                if (!_isLoading) ...[
                  // Device model
                  AnimatedBuilder(
                    animation: _fadeController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          _deviceModel != null ? '📱 Model: $_deviceModel' : '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Device ID
                  AnimatedBuilder(
                    animation: _fadeController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          _deviceId != null ? '🔑 Device ID: $_deviceId' : '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  // Status
                  AnimatedBuilder(
                    animation: _fadeController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          _status != null ? '📡 Status: $_status' : '',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _isSuccess ? Colors.green : Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  // Next button
                  if (_isSuccess)
                    AnimatedBuilder(
                      animation: _buttonScaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _buttonScaleAnimation.value,
                          child: ElevatedButton.icon(
                            onPressed: _goToHomeScreen,
                            icon: const Icon(Icons.arrow_forward, color: Colors.white),
                            label: const Text(
                              "Next",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C4B4),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              shadowColor: Colors.black.withOpacity(0.3),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _buttonController.dispose();
    super.dispose();
  }
}