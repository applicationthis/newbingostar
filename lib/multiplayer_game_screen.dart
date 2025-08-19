import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'board_screen.dart'; // Make sure this exists

class MultiplayerGameScreen extends StatefulWidget {
  final String roomId;
  final bool isCreator;

  const MultiplayerGameScreen({
    super.key,
    required this.roomId,
    required this.isCreator,
  });

  @override
  State<MultiplayerGameScreen> createState() => _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> players = [];

  @override
  void initState() {
    super.initState();
    _initializeRoom();
  }

  Future<void> _initializeRoom() async {
    final roomRef = _firestore.collection('rooms').doc(widget.roomId);

    final snapshot = await roomRef.get();

    if (widget.isCreator) {
      if (!snapshot.exists) {
        // Create room with creator
        await roomRef.set({
          'players': ['Player1'],
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          players = ['Player1'];
        });
      }
    } else {
      if (snapshot.exists) {
        // Join room
        List<dynamic> existingPlayers = snapshot.data()?['players'] ?? [];
        String newPlayer = 'Player${existingPlayers.length + 1}';

        await roomRef.update({
          'players': FieldValue.arrayUnion([newPlayer]),
        });

        setState(() {
          players = List<String>.from(existingPlayers)..add(newPlayer);
        });
      } else {
        // Room not found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Room does not exist')),
        );
        Navigator.pop(context);
      }
    }

    // Listen to player updates
    roomRef.snapshots().listen((doc) {
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            players = List<String>.from(data['players'] ?? []);
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer Bingo Room'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Room ID: ${widget.roomId}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Players in Room:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            ...players.map((player) => ListTile(
              leading: const Icon(Icons.person),
              title: Text(player),
            )),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BoardScreen(
                      roomId: widget.roomId,
                      players: players,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child:
              const Text('Start Game', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
