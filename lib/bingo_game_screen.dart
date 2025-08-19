import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:confetti/confetti.dart';
import 'package:newbingostar/dashboard_screen.dart';

class BingoGameScreen extends StatefulWidget {
  const BingoGameScreen({super.key});

  @override
  State<BingoGameScreen> createState() => _BingoGameScreenState();
}

class _BingoGameScreenState extends State<BingoGameScreen> with TickerProviderStateMixin {
  final int gridSize = 5;
  List<List<int>> board = [];
  List<List<bool>> marked = [];
  List<int> numbersPool = List.generate(75, (i) => i + 1);
  List<int> drawnNumbers = [];
  String status = "Tap 'Draw' to start";
  Timer? timer;
  bool gameOver = false;
  int coins = 100;
  int score = 0;
  int secondsLeft = 60;
  bool isPaused = false;

  final AudioPlayer _audioPlayer = AudioPlayer();
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _powerupController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _powerupAnimation;
  late Animation<Color?> _timerColorAnimation;

  // Map to store animation controllers for each grid tile
  final Map<String, AnimationController> _tileControllers = {};
  final Map<String, Animation<double>> _tileScaleAnimations = {};
  final Map<String, Animation<double>> _tileOpacityAnimations = {};

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _powerupController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticInOut),
    );
    _powerupAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _powerupController, curve: Curves.easeInOut),
    );
    _timerColorAnimation = ColorTween(
      begin: const Color(0xFF00C4B4),
      end: Colors.red,
    ).animate(
      CurvedAnimation(
        parent: AnimationController(
          vsync: this,
          duration: const Duration(seconds: 60),
        )..forward(),
        curve: Curves.linear,
      ),
    );

    // Initialize tile animation controllers
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final key = '$i-$j';
        _tileControllers[key] = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        );
        _tileScaleAnimations[key] = Tween<double>(begin: 0.8, end: 1.0).animate(
          CurvedAnimation(parent: _tileControllers[key]!, curve: Curves.easeOutBack),
        );
        _tileOpacityAnimations[key] = Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(parent: _tileControllers[key]!, curve: Curves.easeIn),
        );
      }
    }

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user logged in during _checkAuth");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Not logged in. Please log in to save progress."),
            backgroundColor: Color(0xFF7B1FA2),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      print("Authenticated user UID: ${user.uid}");
      await _fetchLastScoreAndCoins(user.uid);
      _generateBoard();
      _startTimer();
    }
  }

  Future<void> _fetchLastScoreAndCoins(String uid) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("scores")
          .orderBy("timestamp", descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() {
          score = data['score'] ?? 0;
          coins = data['coins'] ?? 100;
        });
        print("Fetched score: $score, coins: $coins for UID: $uid");
      } else {
        print("No previous scores found for UID: $uid, using defaults");
      }
    } catch (e) {
      print("Error fetching score and coins: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load score and coins: $e"),
            backgroundColor: const Color(0xFF7B1FA2),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _startTimer() {
    if (mounted) {
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || isPaused || gameOver) return;
        if (secondsLeft <= 0) {
          _endGame(" Time's up!");
        } else {
          setState(() => secondsLeft--);
        }
      });
    }
  }

  void _togglePause() {
    if (gameOver) return;
    setState(() {
      isPaused = !isPaused;
      status = isPaused ? "Game Paused" : "Tap 'Draw' to continue";
    });
  }

  void _generateBoard() {
    final random = Random();
    board.clear();
    marked.clear();
    List<int> used = [];
    for (int i = 0; i < gridSize; i++) {
      List<int> row = [];
      List<bool> rowMark = [];
      for (int j = 0; j < gridSize; j++) {
        int num;
        do {
          num = random.nextInt(75) + 1;
        } while (used.contains(num));
        used.add(num);
        row.add(num);
        rowMark.add(false);
      }
      board.add(row);
      marked.add(rowMark);
    }

    marked[2][2] = true;
    board[2][2] = 0;

    numbersPool = List.generate(75, (i) => i + 1);
    drawnNumbers.clear();
    status = "Tap 'Draw' to start";
    gameOver = false;
    secondsLeft = 60;
    isPaused = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _drawNumber() async {
    if (gameOver || numbersPool.isEmpty || isPaused) return;
    final random = Random();
    int index = random.nextInt(numbersPool.length);
    int number = numbersPool[index];
    numbersPool.removeAt(index);
    drawnNumbers.add(number);
    coins -= 1;

    bool matched = _markBoard(number);
    if (matched) {
      try {
        await _audioPlayer.play(AssetSource('audio/match.mp3'));
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 200);
        }
        // Trigger tile animations for matched numbers
        for (int i = 0; i < gridSize; i++) {
          for (int j = 0; j < gridSize; j++) {
            if (board[i][j] == number) {
              _tileControllers['$i-$j']?.forward(from: 0.0);
            }
          }
        }
      } catch (e) {
        print("Error playing match sound: $e");
      }
    }

    _checkWin();
    if (mounted) {
      setState(() {
        status = "Drawn Number: $number";
      });
    }
  }

  bool _markBoard(int number) {
    bool matched = false;
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (board[i][j] == number) {
          marked[i][j] = true;
          matched = true;
        }
      }
    }
    return matched;
  }

  void _checkWin() {
    for (int i = 0; i < gridSize; i++) {
      if (marked[i].every((e) => e)) {
        _win("You win! (Row ${i + 1})");
        return;
      }
    }
    for (int j = 0; j < gridSize; j++) {
      bool colWin = true;
      for (int i = 0; i < gridSize; i++) {
        if (!marked[i][j]) {
          colWin = false;
          break;
        }
      }
      if (colWin) {
        _win("You win! (Column ${j + 1})");
        return;
      }
    }

    bool diag1 = true;
    for (int i = 0; i < gridSize; i++) {
      if (!marked[i][i]) {
        diag1 = false;
        break;
      }
    }
    if (diag1) {
      _win("You win! (Diagonal)");
      return;
    }

    bool diag2 = true;
    for (int i = 0; i < gridSize; i++) {
      if (!marked[gridSize - 1 - i][i]) {
        diag2 = false;
        break;
      }
    }
    if (diag2) {
      _win("You win! (Diagonal)");
      return;
    }

    if (numbersPool.isEmpty) {
      _endGame("Game over! No more numbers.");
    }
  }

  void _win(String message) async {
    try {
      await _audioPlayer.play(AssetSource('bingo.mp3'));
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(duration: 500);
      }
      _confettiController.play(); // Start confetti
      _shakeController.repeat(reverse: true); // Start shake animation
    } catch (e) {
      print("Error playing win sound: $e");
    }
    score += 100;
    coins += 50;

    await _saveScoreToFirestore();

    if (mounted) {
      setState(() {
        gameOver = true;
        status = message;
      });
      timer?.cancel();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "Bingo!",
            style: TextStyle(
              color: Color(0xFF7B1FA2),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "$message\nScore: $score\nCoins: $coins",
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confettiController.stop();
                _shakeController.stop();
                _generateBoard();
              },
              child: const Text(
                "Play Again",
                style: TextStyle(color: Color(0xFF7B1FA2)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8F00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _confettiController.stop();
                _shakeController.stop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                );
              },
              child: const Text("Exit"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveScoreToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user logged in during _saveScoreToFirestore");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Not logged in. Please log in to save score and coins."),
            backgroundColor: Color(0xFF7B1FA2),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
      return;
    }
    print("Attempting to save score for user UID: ${user.uid}");
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("scores")
          .add({
        "score": score,
        "coins": coins,
        "timestamp": FieldValue.serverTimestamp(),
      });
      print("Successfully saved score: $score, coins: $coins for UID: ${user.uid}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Score and coins saved successfully!"),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Firestore error in _saveScoreToFirestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save score and coins: $e"),
            backgroundColor: const Color(0xFF7B1FA2),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _usePowerup(String type) {
    if (gameOver || isPaused) return;
    if (coins < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Not enough coins! Need 20 coins."),
          backgroundColor: const Color(0xFF7B1FA2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      coins -= 20;
      switch (type) {
        case "autoMark":
          if (numbersPool.isNotEmpty) {
            _drawNumber();
            status = "Powerup: Auto-marked a number!";
            _powerupController.forward(from: 0.0);
          }
          break;
        case "extraTime":
          secondsLeft += 15;
          status = "Powerup: +15 seconds added!";
          _powerupController.forward(from: 0.0);
          break;
      }
    });
    _saveScoreToFirestore();
  }

  void _endGame(String message) {
    if (!mounted) return;
    try {
      setState(() {
        gameOver = true;
        status = message;
      });
      timer?.cancel();
      timer = null;
      _saveScoreToFirestore();
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              "Game Over",
              style: TextStyle(
                color: Color(0xFF7B1FA2),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "$message\nScore: $score\nCoins: $coins",
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _generateBoard();
                },
                child: const Text(
                  "Play Again",
                  style: TextStyle(color: Color(0xFF7B1FA2)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8F00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  );
                },
                child: const Text("Exit"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print("Error in _endGame: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error ending game: $e"),
            backgroundColor: const Color(0xFF7B1FA2),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Color _getTileColor(int i, int j) {
    return marked[i][j] ? const Color(0xFF4CAF50) : Colors.white;
  }

  Widget _buildBingoGrid() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * 20, 0), // Shake effect
          child: child,
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(gridSize, (i) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(gridSize, (j) {
              final num = board[i][j];
              final key = '$i-$j';
              return AnimatedBuilder(
                animation: _tileControllers[key]!,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _tileScaleAnimations[key]!.value,
                    child: Opacity(
                      opacity: _tileOpacityAnimations[key]!.value,
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getTileColor(i, j),
                          border: Border.all(color: const Color(0xFF7B1FA2)),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            num == 0 ? "FREE" : num.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: marked[i][j] ? Colors.white : const Color(0xFF7B1FA2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bingo Mania'),
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateBoard,
            tooltip: "New Game",
          ),
          IconButton(
            icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            onPressed: _togglePause,
            tooltip: isPaused ? "Resume" : "Pause",
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF00695C),
                  Color(0xFF7B1FA2),
                  Color(0xFFFF8F00),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Text(
                        "$secondsLeft sec | $coins | Score: $score",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedBuilder(
                        animation: _timerColorAnimation,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            value: (secondsLeft / 60.0).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(_timerColorAnimation.value!),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          );
                        },
                      ),
                    ],
                  ),
                  Text(
                    status,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  _buildBingoGrid(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: ElevatedButton(
                              onPressed: gameOver || isPaused ? null : _drawNumber,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C4B4),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade400,
                                disabledForegroundColor: Colors.grey.shade600,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 5,
                                shadowColor: Colors.black.withOpacity(0.3),
                              ),
                              child: const Text(
                                'Draw Number',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      AnimatedBuilder(
                        animation: _powerupAnimation,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.yellow.withOpacity(_powerupAnimation.value * 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: PopupMenuButton<String>(
                              onSelected: _usePowerup,
                              icon: const Icon(Icons.bolt, color: Colors.white),
                              tooltip: "Powerups",
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: "autoMark",
                                  child: Text("Auto-Mark (20 coins)"),
                                ),
                                const PopupMenuItem(
                                  value: "extraTime",
                                  child: Text("Extra Time (20 coins)"),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.2,
              colors: const [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _audioPlayer.dispose();
    _confettiController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _powerupController.dispose();
    _timerColorAnimation.parent?.dispose();
    _tileControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }
}

extension on Animation<Color?> {
  get parent => null;
}