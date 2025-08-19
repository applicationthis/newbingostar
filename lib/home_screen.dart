import 'package:flutter/material.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path; // Use alias to avoid conflict

class BingoHomeScreen extends StatefulWidget {
  const BingoHomeScreen({super.key});

  @override
  State<BingoHomeScreen> createState() => _BingoHomeScreenState();
}

class _BingoHomeScreenState extends State<BingoHomeScreen> with SingleTickerProviderStateMixin {
  int selectedBoardSize = 3;
  List<List<int>> board = [];
  List<List<bool>> player1Marked = [];
  List<List<bool>> player2Marked = [];
  final AudioPlayer audioPlayer = AudioPlayer();

  bool hasBingo = false;
  bool isVsAI = false;
  bool isPlayer1Turn = true;
  bool player1Won = false;
  bool player2Won = false;
  bool isDailyChallenge = false;

  String aiDifficulty = 'Easy';
  String gameMode = 'Single Player';

  // Timer-related variables
  Timer? _timer;
  int _secondsRemaining = 10;
  static const int _turnDuration = 10;

  // Theme-related variables
  ThemeMode _themeMode = ThemeMode.light;

  // Reward-related variables
  int coins = 0;
  int diamonds = 0;
  int powerUps = 0;
  int level = 1;
  bool diagonalPuzzleCompleted = false;
  String playerName = 'Player';

  // Animation for reward claim
  bool showRewardAnimation = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // SQLite database
  Database? _database;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    initializeDatabase();
    loadPreferences();
    generateBoard();
  }

  // Initialize SQLite database
  Future<void> initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, 'bingo.db'); // Use path.join

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE leaderboard (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            score INTEGER,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  // Load saved data from shared_preferences
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      coins = prefs.getInt('coins') ?? 0;
      diamonds = prefs.getInt('diamonds') ?? 0;
      powerUps = prefs.getInt('powerUps') ?? 0;
      level = prefs.getInt('level') ?? 1;
      diagonalPuzzleCompleted = prefs.getBool('diagonalPuzzleCompleted') ?? false;
      playerName = prefs.getString('playerName') ?? 'Player';
    });
    await awardDailyBonus();
    await awardHourlyBonus();
    await awardDailyDiamonds();
  }

  // Save data to shared_preferences
  Future<void> savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
    await prefs.setInt('diamonds', diamonds);
    await prefs.setInt('powerUps', powerUps);
    await prefs.setInt('level', level);
    await prefs.setBool('diagonalPuzzleCompleted', diagonalPuzzleCompleted);
    await prefs.setString('playerName', playerName);
  }

  // Daily Free Cash (Base, Level, Puzzle Bonuses)
  Future<void> awardDailyBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastLoginStr = prefs.getString('lastLogin');
    final lastLogin = lastLoginStr != null ? DateTime.parse(lastLoginStr) : null;

    if (lastLogin == null || now.day != lastLogin.day) {
      setState(() {
        coins += 100; // Base bonus
        coins += level * 50; // Level-based bonus
        if (diagonalPuzzleCompleted) {
          coins += 200; // Puzzle bonus
          diagonalPuzzleCompleted = false; // Reset for next day
        }
        showRewardAnimation = true;
      });
      await prefs.setString('lastLogin', now.toIso8601String());
      await savePreferences();
      _triggerRewardAnimation();
    }
  }

  // Hourly Free Bingo Bonus
  Future<void> awardHourlyBonus() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastBonusStr = prefs.getString('lastBonus');
    final lastBonus = lastBonusStr != null ? DateTime.parse(lastBonusStr) : null;

    if (lastBonus == null || now.difference(lastBonus).inHours >= 1) {
      setState(() {
        coins += 50; // Hourly bonus
        showRewardAnimation = true;
      });
      await prefs.setString('lastBonus', now.toIso8601String());
      await savePreferences();
      _triggerRewardAnimation();
    }
  }

  // Daily Free Diamonds
  Future<void> awardDailyDiamonds() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final lastDiamondStr = prefs.getString('lastDiamond');
    final lastDiamond = lastDiamondStr != null ? DateTime.parse(lastDiamondStr) : null;

    if (lastDiamond == null || now.day != lastDiamond.day) {
      setState(() {
        diamonds += 1; // Daily diamond
        showRewardAnimation = true;
      });
      await prefs.setString('lastDiamond', now.toIso8601String());
      await savePreferences();
      _triggerRewardAnimation();
    }
  }

  // Trigger reward animation
  void _triggerRewardAnimation() {
    if (mounted) {
      _animationController.forward().then((_) {
        _animationController.reverse();
        setState(() {
          showRewardAnimation = false;
        });
      });
    }
  }

  // Update SQLite leaderboard
  Future<void> updateLeaderboard(bool isPlayer1Win) async {
    final score = level * 100 + (isPlayer1Win ? 500 : 0);
    final player = gameMode == 'Multiplayer' ? (isPlayer1Win ? 'Player 1' : 'Player 2') : playerName;

    if (_database != null) {
      await _database!.insert(
        'leaderboard',
        {
          'name': player,
          'score': score,
          'timestamp': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Award power-up if player is in top rank
      final topScores = await _database!.query(
        'leaderboard',
        orderBy: 'score DESC',
        limit: 10,
      );
      setState(() {
        if (topScores.isNotEmpty && topScores.first['name'] == player && topScores.first['score'] == score) {
          powerUps += 1;
          showRewardAnimation = true;
          _triggerRewardAnimation();
        }
      });
      await savePreferences();
    }
  }

  // Fetch leaderboard from SQLite
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    if (_database == null) return [];
    final result = await _database!.query(
      'leaderboard',
      orderBy: 'score DESC',
      limit: 10,
    );
    return result;
  }

  // Use power-up to auto-mark a cell
  void usePowerUp() {
    if (powerUps > 0 && !hasBingo) {
      for (int i = 0; i < selectedBoardSize; i++) {
        for (int j = 0; j < selectedBoardSize; j++) {
          if (!player1Marked[i][j] && !player2Marked[i][j]) {
            setState(() {
              if (gameMode == 'Multiplayer' && isPlayer1Turn || !isVsAI) {
                player1Marked[i][j] = true;
                checkBingo(isPlayer1: true);
              } else if (gameMode == 'Multiplayer' && !isPlayer1Turn) {
                player2Marked[i][j] = true;
                checkBingo(isPlayer1: false);
              } else if (isVsAI && isPlayer1Turn) {
                player1Marked[i][j] = true;
                checkBingo(isPlayer1: true);
              }
              powerUps -= 1;
              showRewardAnimation = true;
            });
            playClickSound();
            _triggerRewardAnimation();
            savePreferences();
            return;
          }
        }
      }
    }
  }

  void generateBoard() {
    final Random random = isDailyChallenge ? Random(_getDailySeed()) : Random();
    List<int> numbers = List.generate(selectedBoardSize * selectedBoardSize, (index) => index + 1);
    numbers.shuffle(random);

    board = List.generate(
      selectedBoardSize,
          (i) => List.generate(selectedBoardSize, (j) => numbers[i * selectedBoardSize + j]),
    );

    player1Marked = List.generate(
      selectedBoardSize,
          (i) => List.generate(selectedBoardSize, (j) => false),
    );

    player2Marked = List.generate(
      selectedBoardSize,
          (i) => List.generate(selectedBoardSize, (j) => false),
    );

    hasBingo = false;
    player1Won = false;
    player2Won = false;
    isPlayer1Turn = true;

    if (isVsAI || gameMode == 'Multiplayer') {
      startTimer();
    }
  }

  int _getDailySeed() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return today.codeUnits.reduce((a, b) => a + b);
  }

  Future<void> playClickSound() async {
    await audioPlayer.play(AssetSource('click.mp3'));
  }

  void checkBingo({required bool isPlayer1}) {
    bool bingo = false;
    List<List<bool>> marked = isPlayer1 ? player1Marked : player2Marked;

    for (int i = 0; i < selectedBoardSize; i++) {
      if (marked[i].every((val) => val)) bingo = true;
    }

    for (int j = 0; j < selectedBoardSize; j++) {
      if (List.generate(selectedBoardSize, (i) => marked[i][j]).every((val) => val)) bingo = true;
    }

    if (List.generate(selectedBoardSize, (i) => marked[i][i]).every((val) => val)) {
      bingo = true;
      if (isPlayer1 && !diagonalPuzzleCompleted) {
        setState(() {
          diagonalPuzzleCompleted = true;
          coins += 200;
          showRewardAnimation = true;
        });
        _triggerRewardAnimation();
        savePreferences();
      }
    }
    if (List.generate(selectedBoardSize, (i) => marked[i][selectedBoardSize - 1 - i]).every((val) => val)) bingo = true;

    if (bingo && !hasBingo) {
      setState(() {
        hasBingo = true;
        if (gameMode == 'Multiplayer') {
          if (isPlayer1) {
            player1Won = true;
            showWinDialog("🎉 Player 1 Wins!");
          } else {
            player2Won = true;
            showWinDialog("🎉 Player 2 Wins!");
          }
        } else {
          if (isPlayer1) {
            player1Won = true;
            showWinDialog("🎉 You Win!");
          } else {
            player2Won = true;
            showWinDialog("💻 Computer Wins!");
          }
        }
        level += 1;
        updateLeaderboard(isPlayer1);
      });
      cancelTimer();
      savePreferences();
    }
  }

  void showWinDialog(String message) {
    showDialog(
      context: context, // Use the state's context
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(message, style: TextStyle(color: _themeMode == ThemeMode.light ? Colors.green : Colors.lightGreen)),
        content: Text('Coins: $coins | Diamonds: $diamonds | Power-Ups: $powerUps | Level: $level'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              restartGame();
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  void restartGame() {
    setState(() {
      cancelTimer();
      generateBoard();
    });
  }

  void startTimer() {
    cancelTimer();
    _secondsRemaining = _turnDuration;
    setState(() {});

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        if (gameMode == 'Multiplayer' && !hasBingo) {
          isPlayer1Turn = !isPlayer1Turn;
          startTimer();
        } else if (isVsAI && isPlayer1Turn && !hasBingo) {
          isPlayer1Turn = false;
          aiTurn();
        } else if (isVsAI && !isPlayer1Turn && !hasBingo) {
          isPlayer1Turn = true;
          startTimer();
        }
      }
    });
  }

  void cancelTimer() {
    _timer?.cancel();
    _secondsRemaining = _turnDuration;
    setState(() {});
  }

  Future<void> aiTurn() async {
    if (hasBingo) return;
    cancelTimer();
    await Future.delayed(const Duration(milliseconds: 500));

    List<List<int>> options = [];
    for (int i = 0; i < selectedBoardSize; i++) {
      for (int j = 0; j < selectedBoardSize; j++) {
        if (!player1Marked[i][j] && !player2Marked[i][j]) options.add([i, j]);
      }
    }

    List<int>? bestMove;

    if (aiDifficulty == 'Hard') {
      bestMove = _findWinningMove() ?? _findBlockingMove();
    } else if (aiDifficulty == 'Medium') {
      bestMove = _findBestStrategicMove();
    }

    bestMove ??= (options..shuffle()).first;

    setState(() {
      player2Marked[bestMove![0]][bestMove[1]] = true;
      isPlayer1Turn = true;
    });

    await playClickSound();
    checkBingo(isPlayer1: false);

    if (!hasBingo) {
      startTimer();
    }
  }

  List<int>? _findWinningMove() => _findCriticalMove(markFor: true, marked: player2Marked);
  List<int>? _findBlockingMove() => _findCriticalMove(markFor: true, marked: player1Marked);

  List<int>? _findCriticalMove({required bool markFor, required List<List<bool>> marked}) {
    for (int i = 0; i < selectedBoardSize; i++) {
      int count = 0;
      int empty = -1;
      for (int j = 0; j < selectedBoardSize; j++) {
        if (marked[i][j] == markFor) count++;
        else if (!player1Marked[i][j] && !player2Marked[i][j]) empty = j;
      }
      if (count == selectedBoardSize - 1 && empty != -1) return [i, empty];
    }

    for (int j = 0; j < selectedBoardSize; j++) {
      int count = 0;
      int empty = -1;
      for (int i = 0; i < selectedBoardSize; i++) {
        if (marked[i][j] == markFor) count++;
        else if (!player1Marked[i][j] && !player2Marked[i][j]) empty = i;
      }
      if (count == selectedBoardSize - 1 && empty != -1) return [empty, j];
    }

    int diagCount = 0, emptyDiag = -1;
    for (int i = 0; i < selectedBoardSize; i++) {
      if (marked[i][i] == markFor) diagCount++;
      else if (!player1Marked[i][i] && !player2Marked[i][i]) emptyDiag = i;
    }
    if (diagCount == selectedBoardSize - 1 && emptyDiag != -1) return [emptyDiag, emptyDiag];

    int antiCount = 0, emptyAnti = -1;
    for (int i = 0; i < selectedBoardSize; i++) {
      if (marked[i][selectedBoardSize - 1 - i] == markFor) antiCount++;
      else if (!player1Marked[i][selectedBoardSize - 1 - i] && !player2Marked[i][selectedBoardSize - 1 - i]) emptyAnti = i;
    }
    if (antiCount == selectedBoardSize - 1 && emptyAnti != -1) {
      return [emptyAnti, selectedBoardSize - 1 - emptyAnti];
    }

    return null;
  }

  List<int>? _findBestStrategicMove() {
    List<List<int>> options = [];
    for (int i = 0; i < selectedBoardSize; i++) {
      for (int j = 0; j < selectedBoardSize; j++) {
        if (!player1Marked[i][j] && !player2Marked[i][j]) {
          int score = _countMarks(i, j, player2Marked);
          options.add([i, j, score]);
        }
      }
    }

    if (options.isEmpty) return null;

    options.sort((a, b) => b[2].compareTo(a[2]));
    return [options.first[0], options.first[1]];
  }

  int _countMarks(int row, int col, List<List<bool>> marked) {
    int count = 0;
    for (int i = 0; i < selectedBoardSize; i++) {
      if (marked[row][i]) count++;
      if (marked[i][col]) count++;
    }
    if (row == col) {
      for (int i = 0; i < selectedBoardSize; i++) {
        if (marked[i][i]) count++;
      }
    }
    if (row + col == selectedBoardSize - 1) {
      for (int i = 0; i < selectedBoardSize; i++) {
        if (marked[i][selectedBoardSize - 1 - i]) count++;
      }
    }
    return count;
  }

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  // Show dialog to set player name
  void showNameDialog() {
    final controller = TextEditingController(text: playerName);
    showDialog(
      context: context, // Use the state's context
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Set Player Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter your name'),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  playerName = controller.text.trim();
                });
                savePreferences();
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Navigate to Profile Screen
  void showProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (BuildContext navContext) => ProfileScreen(
          themeMode: _themeMode,
          playerName: playerName,
          coins: coins,
          diamonds: diamonds,
          powerUps: powerUps,
          level: level,
          onNameChanged: (newName) {
            setState(() {
              playerName = newName;
            });
            savePreferences();
          },
          onResetData: () async {
            setState(() {
              coins = 0;
              diamonds = 0;
              powerUps = 0;
              level = 1;
              diagonalPuzzleCompleted = false;
            });
            await savePreferences();
          },
        ),
      ),
    );
  }

  Widget buildBoard() {
    return GridView.builder(
      itemCount: selectedBoardSize * selectedBoardSize,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: selectedBoardSize,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        int i = index ~/ selectedBoardSize;
        int j = index % selectedBoardSize;
        return GestureDetector(
          onTap: () async {
            if (!hasBingo &&
                !player1Marked[i][j] &&
                !player2Marked[i][j] &&
                (gameMode == 'Multiplayer' || (isVsAI && isPlayer1Turn))) {
              cancelTimer();
              setState(() {
                if (gameMode == 'Multiplayer') {
                  if (isPlayer1Turn) {
                    player1Marked[i][j] = true;
                    checkBingo(isPlayer1: true);
                    if (!hasBingo) isPlayer1Turn = false;
                  } else {
                    player2Marked[i][j] = true;
                    checkBingo(isPlayer1: false);
                    if (!hasBingo) isPlayer1Turn = true;
                  }
                } else {
                  player1Marked[i][j] = true;
                  checkBingo(isPlayer1: true);
                  if (isVsAI && !hasBingo) {
                    isPlayer1Turn = false;
                    aiTurn();
                  }
                }
              });
              await playClickSound();
              if (!hasBingo && (gameMode == 'Multiplayer' || isVsAI)) {
                startTimer();
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: player1Marked[i][j]
                  ? Colors.green
                  : player2Marked[i][j]
                  ? Colors.red
                  : (_themeMode == ThemeMode.light ? Colors.white : Colors.grey[800]),
              border: Border.all(color: _themeMode == ThemeMode.light ? Colors.black : Colors.white),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              board[i][j].toString(),
              style: TextStyle(
                fontSize: 22,
                color: player1Marked[i][j] || player2Marked[i][j]
                    ? Colors.white
                    : (_themeMode == ThemeMode.light ? Colors.black : Colors.white),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildVictoryText() {
    if (hasBingo) {
      String message;
      if (gameMode == 'Multiplayer') {
        message = player1Won ? "🎉 Player 1 Wins!" : player2Won ? "🎉 Player 2 Wins!" : "Bingo!";
      } else {
        message = player1Won ? "🎉 You Win!" : player2Won ? "💻 Computer Wins!" : "Bingo!";
      }
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(
          message,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _themeMode == ThemeMode.light ? Colors.green : Colors.lightGreen,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget buildTimer() {
    if ((isVsAI || gameMode == 'Multiplayer') && !hasBingo) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          gameMode == 'Multiplayer'
              ? (isPlayer1Turn ? 'Player 1 Turn: $_secondsRemaining seconds' : 'Player 2 Turn: $_secondsRemaining seconds')
              : (isPlayer1Turn ? 'Your Turn: $_secondsRemaining seconds' : 'AI Turn: $_secondsRemaining seconds'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _themeMode == ThemeMode.light ? Colors.black : Colors.white,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.deepPurple[300],
        scaffoldBackgroundColor: Colors.grey[900],
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: _themeMode,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('🎯 Bingo Game'),
          actions: [
            IconButton(
              icon: Icon(_themeMode == ThemeMode.light ? Icons.dark_mode : Icons.light_mode),
              onPressed: toggleTheme,
            ),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: showProfile,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Display rewards with animation
              ScaleTransition(
                scale: _animation,
                child: Card(
                  elevation: 4,
                  color: _themeMode == ThemeMode.light ? Colors.white : Colors.grey[800],
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: showNameDialog,
                          child: Text(
                            'Player: $playerName',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _themeMode == ThemeMode.light ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              'Coins: $coins',
                              style: TextStyle(
                                fontSize: 16,
                                color: _themeMode == ThemeMode.light ? Colors.black : Colors.white,
                              ),
                            ),
                            Text(
                              'Diamonds: $diamonds',
                              style: TextStyle(
                                fontSize: 16,
                                color: _themeMode == ThemeMode.light ? Colors.black : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              'Power-Ups: $powerUps',
                              style: TextStyle(
                                fontSize: 16,
                                color: _themeMode == ThemeMode.light ? Colors.black : Colors.white,
                              ),
                            ),
                            Text(
                              'Level: $level',
                              style: TextStyle(
                                fontSize: 16,
                                color: _themeMode == ThemeMode.light ? Colors.black : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      value: selectedBoardSize,
                      items: [3, 4, 5].map((size) => DropdownMenuItem(value: size, child: Text('${size}x$size'))).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedBoardSize = value!;
                          generateBoard();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: DropdownButton<String>(
                      value: gameMode,
                      items: ['Single Player', 'Multiplayer']
                          .map((mode) => DropdownMenuItem(value: mode, child: Text(mode)))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          gameMode = value!;
                          isVsAI = gameMode == 'Single Player';
                          generateBoard();
                        });
                      },
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: aiDifficulty,
                      items: ['Easy', 'Medium', 'Hard']
                          .map((level) => DropdownMenuItem(value: level, child: Text('AI: $level')))
                          .toList(),
                      onChanged: gameMode == 'Single Player'
                          ? (value) {
                        setState(() {
                          aiDifficulty = value!;
                        });
                      }
                          : null,
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: isDailyChallenge,
                          onChanged: (val) {
                            setState(() {
                              isDailyChallenge = val!;
                              generateBoard();
                            });
                          },
                        ),
                        const Text("Daily Challenge"),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              buildTimer(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bolt),
                  label: Text('Use Power-Up ($powerUps)'),
                  onPressed: powerUps > 0 ? usePowerUp : null,
                ),
              ),
              buildBoard(),
              const SizedBox(height: 16),
              buildVictoryText(),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Restart"),
                onPressed: restartGame,
              ),
              const SizedBox(height: 10),
              if (gameMode != 'Multiplayer')
                ElevatedButton.icon(
                  icon: const Icon(Icons.smart_toy),
                  label: const Text("Play vs Computer"),
                  onPressed: () {
                    setState(() {
                      gameMode = 'Single Player';
                      isVsAI = true;
                      isPlayer1Turn = true;
                      generateBoard();
                    });
                  },
                ),
              if (gameMode != 'Single Player')
                ElevatedButton.icon(
                  icon: const Icon(Icons.group),
                  label: const Text("Play Multiplayer"),
                  onPressed: () {
                    setState(() {
                      gameMode = 'Multiplayer';
                      isVsAI = false;
                      isPlayer1Turn = true;
                      generateBoard();
                    });
                  },
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.leaderboard),
                label: const Text("View Leaderboard"),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) => AlertDialog(
                      title: const Text('Leaderboard'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: getLeaderboard(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }
                            final leaderboard = snapshot.data ?? [];
                            return ListView.builder(
                              shrinkWrap: true,
                              itemCount: leaderboard.length,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  leading: Text('${index + 1}.'),
                                  title: Text(leaderboard[index]['name'] ?? 'Unknown'),
                                  trailing: Text('Score: ${leaderboard[index]['score'] ?? 0}'),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text("OK"),
                        ),
                      ],
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

  @override
  void dispose() {
    cancelTimer();
    audioPlayer.dispose();
    _animationController.dispose();
    _database?.close();
    super.dispose();
  }
}

class ProfileScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final String playerName;
  final int coins;
  final int diamonds;
  final int powerUps;
  final int level;
  final Function(String) onNameChanged;
  final Function() onResetData;

  const ProfileScreen({
    super.key,
    required this.themeMode,
    required this.playerName,
    required this.coins,
    required this.diamonds,
    required this.powerUps,
    required this.level,
    required this.onNameChanged,
    required this.onResetData,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playerName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.themeMode == ThemeMode.light ? Colors.white : Colors.grey[900],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: widget.themeMode == ThemeMode.light ? Colors.deepPurple : Colors.deepPurple[300],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Player Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.themeMode == ThemeMode.light ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Player Name',
                  border: OutlineInputBorder(),
                ),
                maxLength: 20,
                onChanged: (value) {
                  widget.onNameChanged(value.trim());
                },
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                color: widget.themeMode == ThemeMode.light ? Colors.white : Colors.grey[800],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Coins: ${widget.coins}',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.themeMode == ThemeMode.light ? Colors.black : Colors.white,
                        ),
                      ),
                      Text(
                        'Diamonds: ${widget.diamonds}',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.themeMode == ThemeMode.light ? Colors.black : Colors.white,
                        ),
                      ),
                      Text(
                        'Power-Ups: ${widget.powerUps}',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.themeMode == ThemeMode.light ? Colors.black : Colors.white,
                        ),
                      ),
                      Text(
                        'Level: ${widget.level}',
                        style: TextStyle(
                          fontSize: 16,
                          color: widget.themeMode == ThemeMode.light ? Colors.black : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Data'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) => AlertDialog(
                      title: const Text('Confirm Reset'),
                      content: const Text('Are you sure you want to reset all your progress?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            widget.onResetData();
                            Navigator.of(dialogContext).pop();
                            setState(() {
                              _nameController.text = widget.playerName;
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ],
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
}