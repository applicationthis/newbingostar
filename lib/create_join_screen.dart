import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'multiplayer_game_screen.dart';

class CreateJoinScreen extends StatefulWidget {
  const CreateJoinScreen({super.key});

  @override
  State<CreateJoinScreen> createState() => _CreateJoinScreenState();
}

class _CreateJoinScreenState extends State<CreateJoinScreen> {
  final TextEditingController roomIdController = TextEditingController();
  bool isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _createRoom() async {
    setState(() => isLoading = true);

    final roomId = const Uuid().v4().substring(0, 6).toUpperCase();

    await _firestore.collection('rooms').doc(roomId).set({
      'roomId': roomId,
      'createdAt': FieldValue.serverTimestamp(),
      'players': 1,
    });

    setState(() => isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiplayerGameScreen(roomId: roomId, isCreator: true),
      ),
    );
  }

  void _joinRoom() async {
    final roomId = roomIdController.text.trim().toUpperCase();

    if (roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Room ID')),
      );
      return;
    }

    setState(() => isLoading = true);

    final roomDoc = await _firestore.collection('rooms').doc(roomId).get();

    if (roomDoc.exists) {
      await _firestore.collection('rooms').doc(roomId).update({
        'players': FieldValue.increment(1),
      });

      setState(() => isLoading = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerGameScreen(roomId: roomId, isCreator: false),
        ),
      );
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room does not exist')),
      );
    }
  }

  @override
  void dispose() {
    roomIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiplayer Bingo'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Room'),
              onPressed: isLoading ? null : _createRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: roomIdController,
              decoration: InputDecoration(
                labelText: 'Enter Room ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Join Room'),
              onPressed: isLoading ? null : _joinRoom,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            if (isLoading) const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          ],
        ),
      ),
    );
  }
}
