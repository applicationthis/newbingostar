import 'package:flutter/material.dart';
import 'dart:async';
import 'device_info_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _indicatorController;
  late AnimationController _shimmerController;
  late AnimationController _iconController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<double> _indicatorAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();

    // Logo pulse animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _logoController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _logoController.forward();
      }
    });
    _logoController.forward();

    // Text fade animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textController.forward();

    // Loading indicator scale animation
    _indicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _indicatorAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _indicatorController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _indicatorController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _indicatorController.forward();
      }
    });
    _indicatorController.forward();

    // Shimmer background animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _shimmerAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shimmerController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _shimmerController.forward();
      }
    });
    _shimmerController.forward();

    // Icon bounce animation
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _iconAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.bounceOut),
    );
    _iconController.forward();

    // Navigate to DeviceInfoScreen after 3 seconds
    Timer(const Duration(seconds: 8), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DeviceInfoScreen()),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _indicatorController.dispose();
    _shimmerController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
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
          ),
          // Shimmer overlay
          AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(_shimmerAnimation.value),
                      Colors.white.withOpacity(_shimmerAnimation.value * 0.5),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo with pulse animation
                    ScaleTransition(
                      scale: _logoAnimation,
                      child: Image.asset(
                        'assets/bingo.png', // Ensure this asset exists
                        width: 120,
                        height: 120,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Star icon with bounce animation
                    AnimatedBuilder(
                      animation: _iconAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _iconAnimation.value,
                          child: const Icon(
                            Icons.star,
                            color: Color(0xFFFFCA28), // Amber
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                // Welcome text with fade animation
                AnimatedBuilder(
                  animation: _textAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _textAnimation.value,
                      child: const Text(
                        'Welcome to Bingo App',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFF8E1), // Light Cream
                          letterSpacing: 1.2,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Loading indicator with scale animation
                AnimatedBuilder(
                  animation: _indicatorAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _indicatorAnimation.value,
                      child: const CircularProgressIndicator(
                        color: Color(0xFFFFCA28), // Amber
                        strokeWidth: 2.5,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}