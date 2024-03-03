import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CreateTeamPage extends StatefulWidget {
  static const String route = 'CreateTeam';
  @override
  _CreateTeamPageState createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  final _teamIdController = TextEditingController();
  List<TextEditingController> _userIdControllers = [];

  void _addUserIdField() {
    TextEditingController newController = TextEditingController();
    setState(() {
      _userIdControllers.add(newController);
    });
  }

  void _removeUserIdField(int index) {
    setState(() {
      _userIdControllers.removeAt(index);
    });
  }

  void _createTeam() async {
    final teamId = _teamIdController.text.trim();
    final userIds =
        _userIdControllers.map((controller) => controller.text.trim()).toList();
    if (teamId.isEmpty || userIds.isEmpty) {
      return;
    }

    await FirebaseFirestore.instance.collection('teams').doc(teamId).set({
      'teamId': teamId,
      'userIds': userIds,
    });

    for (var userId in userIds) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'teamId': teamId});
      } catch (e) {
        print('Error updating user $userId: $e');
      }
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create New Team'),
        backgroundColor: Colors.grey[500],
      ),
      backgroundColor: Colors.grey[300],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _teamIdController,
                decoration: InputDecoration(labelText: 'Team ID'),
              ),
              ..._userIdControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                TextEditingController controller = entry.value;

                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: 'User ID ${idx + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline),
                      onPressed: () => _removeUserIdField(idx),
                    ),
                  ],
                );
              }).toList(),
              ElevatedButton(
                onPressed: _addUserIdField,
                child: Text('Add User ID'),
              ),
              ElevatedButton(
                onPressed: _createTeam,
                child: Text('Create Team'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
