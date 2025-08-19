import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BoardScreen extends StatefulWidget {
  final String roomId;
  final List<String> players;
  final int boardSize;
  final bool isAI;

  const BoardScreen({
    super.key,
    required this.roomId,
    required this.players,
    this.boardSize = 5,
    this.isAI = false,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late List<List<int>> board;
  late List<List<bool>> marked;
  int currentPlayerIndex = 0;
  String? winner;
  late FirebaseFirestore firestore;

  @override
  void initState() {
    super.initState();
    firestore = FirebaseFirestore.instance;
    generateBoard();
    listenToMoves();
  }

  void generateBoard() {
    int boardSize = widget.boardSize > 0 ? widget.boardSize : 5;
    int totalCells = boardSize * boardSize;
    List<int> numbers = List.generate(totalCells, (index) => index + 1);
    numbers.shuffle();

    board = List.generate(
      boardSize,
          (i) => List.generate(boardSize, (j) => numbers[i * boardSize + j]),
    );

    marked = List.generate(
      boardSize,
          (i) => List.generate(boardSize, (j) => false),
    );

    firestore.collection('games').doc(widget.roomId).set({
      'turn': widget.players[0],
      'boardSize': boardSize,
    });

    firestore
        .collection('games')
        .doc(widget.roomId)
        .collection('boards')
        .doc(widget.players[currentPlayerIndex])
        .set({'board': board});
  }

  void listenToMoves() {
    firestore
        .collection('games')
        .doc(widget.roomId)
        .collection('moves')
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        int number = doc['number'];
        markNumber(number);
      }
    });

    firestore
        .collection('games')
        .doc(widget.roomId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        String current = doc['turn'];
        setState(() {
          currentPlayerIndex = widget.players.indexOf(current);
        });
      }
    });
  }

  void markNumber(int number) {
    for (int i = 0; i < widget.boardSize; i++) {
      for (int j = 0; j < widget.boardSize; j++) {
        if (board[i][j] == number) {
          setState(() {
            marked[i][j] = true;
          });
        }
      }
    }
    checkWin();
  }

  void playMove(int i, int j) {
    if (winner != null || marked[i][j]) return;

    int number = board[i][j];
    firestore
        .collection('games')
        .doc(widget.roomId)
        .collection('moves')
        .add({'number': number});

    int nextIndex = (currentPlayerIndex + 1) % widget.players.length;
    firestore
        .collection('games')
        .doc(widget.roomId)
        .update({'turn': widget.players[nextIndex]});
  }

  void checkWin() {
    bool isWin = false;

    // Check rows
    for (int i = 0; i < widget.boardSize; i++) {
      if (marked[i].every((e) => e)) isWin = true;
    }

    // Check columns
    for (int j = 0; j < widget.boardSize; j++) {
      bool colWin = true;
      for (int i = 0; i < widget.boardSize; i++) {
        if (!marked[i][j]) colWin = false;
      }
      if (colWin) isWin = true;
    }

    // Check diagonals
    bool diag1 = true;
    bool diag2 = true;
    for (int i = 0; i < widget.boardSize; i++) {
      if (!marked[i][i]) diag1 = false;
      if (!marked[i][widget.boardSize - i - 1]) diag2 = false;
    }
    if (diag1 || diag2) isWin = true;

    if (isWin && winner == null) {
      setState(() {
        winner = widget.players[currentPlayerIndex];
      });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Bingo!"),
          content: Text("$winner has won!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bingo Multiplayer"),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text("Current Turn: ${widget.players[currentPlayerIndex]}"),
          const SizedBox(height: 10),
          if (winner != null)
            Text(
              "$winner WON!",
              style: const TextStyle(fontSize: 24, color: Colors.green),
            ),
          const SizedBox(height: 10),
          for (int i = 0; i < widget.boardSize; i++)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int j = 0; j < widget.boardSize; j++)
                  GestureDetector(
                    onTap: () => playMove(i, j),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: marked[i][j]
                            ? Colors.green
                            : Colors.blueAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          board[i][j].toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                    ),
                  )
              ],
            ),
        ],
      ),
    );
  }
}
