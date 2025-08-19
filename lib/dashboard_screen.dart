import 'package:flutter/material.dart';
import 'bingo_game_screen.dart'; // Make sure this import path is correct

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _buttonController;
  late List<AnimationController> _tileControllers;
  late AnimationController _iconController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _buttonScaleAnimation;
  late List<Animation<double>> _tileScaleAnimations;
  late Animation<double> _iconBounceAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Initialize button animation
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    // Initialize tile scale animations (9 feature tiles)
    _tileControllers = List.generate(
      9,
          (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _tileScaleAnimations = _tileControllers.map((controller) {
      return Tween<double>(begin: 0.9, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      );
    }).toList();

    // Initialize icon bounce animation
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _iconBounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.bounceOut),
    );

    // Start animations with staggered delays
    _fadeController.forward();
    for (int i = 0; i < _tileControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) _tileControllers[i].forward();
      });
    }
    _iconController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎯 Absolute Bingo Dashboard"),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Center(
                      child: Text(
                        "READY TO PLAY FREE BINGO GAMES OFFLINE AT YOUR OWN SPEED?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _tileScaleAnimations[0],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[0].value,
                    child: featureTile("⭐ FREE bingo play", "Get free bingo coins every 4 hours—hellooo bingo freebies!!"),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _tileScaleAnimations[1],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[1].value,
                    child: featureTile("⭐ FUN bingo rooms", "Play mini games and themed bingo rounds."),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _tileScaleAnimations[2],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[2].value,
                    child: featureTile("⭐ GENEROUS payouts", "Enjoy great bingo odds and big wins!"),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _tileScaleAnimations[3],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[3].value,
                    child: featureTile("⭐ UP TO 8 BINGO CARDS", "Now available - play 8 cards in a room!"),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _tileScaleAnimations[4],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[4].value,
                    child: featureTile("⭐ OFFLINE OR ONLINE PLAY", "No WiFi? No problem! Play anytime, anywhere."),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _tileScaleAnimations[5],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[5].value,
                    child: featureTile("⭐ PAUSE the game", "Take a break whenever you want."),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _tileScaleAnimations[6],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[6].value,
                    child: featureTile("⭐ CUSTOM SPEED", "Play at your own pace: fast or slow."),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _tileScaleAnimations[7],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[7].value,
                    child: featureTile("⭐ WIN POWERUPS", "Unlock special abilities at higher levels."),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _tileScaleAnimations[8],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[8].value,
                    child: featureTile("⭐ DOUBLE & TRIPLE BINGO", "Multiply your fun and rewards!"),
                  );
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: AnimatedBuilder(
                  animation: _buttonScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _buttonScaleAnimation.value,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, color: Colors.white),
                        label: const Text(
                          "Start Playing",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        onPressed: () {
                          _buttonController.forward().then((_) {
                            _buttonController.reverse();
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const BingoGameScreen()),
                            );
                          });
                        },
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
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Divider(color: Colors.white),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "🎓 New to Bingo?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "American Bingo uses a 75-ball 5x5 grid. Match 5 numbers across, down, or diagonally and call BINGO to win!",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "💬 Need Help?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "Send us a message in-game! We respond to all messages.",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "📢 Follow us: facebook.com/AbsoluteBingo",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Divider(color: Colors.white),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "⚠️ Disclaimer:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "This app offers digital content purchases with real money. Disable in-app purchases in settings to avoid payments.",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      "This game does not offer real money gambling or an opportunity to win real prizes.",
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget featureTile(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        leading: AnimatedBuilder(
          animation: _iconBounceAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _iconBounceAnimation.value,
              child: const Icon(Icons.star, color: Colors.orange),
            );
          },
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _buttonController.dispose();
    for (var controller in _tileControllers) {
      controller.dispose();
    }
    _iconController.dispose();
    super.dispose();
  }
}