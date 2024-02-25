import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssignTask extends StatefulWidget {
  static const String route = 'AssignTask';
  const AssignTask({Key? key}) : super(key: key);

  @override
  _AssignTaskState createState() => _AssignTaskState();
}

class _AssignTaskState extends State<AssignTask> {
  String newTask = '';
  String id = '';
  DateTime dueDate = DateTime.now();
  dynamic user;
  final User? uuser = FirebaseAuth.instance.currentUser;
  String assignTo = 'Employee'; // New variable to track the selection
  final List<String> assignOptions = [
    'Employee',
    'Team'
  ]; // Options for the dropdown

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != dueDate)
      setState(() {
        dueDate = picked;
      });
  }

  void saveTasksToFirestore() async {
    if (assignTo == 'Employee') {
      saveEmployeeTaskToFirestore();
    } else {
      saveTeamTaskToFirestore();
    }
  }

  void saveEmployeeTaskToFirestore() async {
    user = await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .get()
        .then((value) => value.data());

    if (user == null) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('User not found'),
          );
        },
      );
      return;
    }

    await FirebaseFirestore.instance.collection('tasks').doc(id).set({
      'tasks': FieldValue.arrayUnion([
        {
          "task": newTask,
          "dueDate": dueDate.toString(),
          "userId": uuser?.displayName //id saved as user name
        }
      ])
    }, SetOptions(merge: true));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text('Task saved successfully'),
        );
      },
    );
  }

  void saveTeamTaskToFirestore() async {
    final team = await FirebaseFirestore.instance
        .collection('teams')
        .doc(id)
        .get()
        .then((value) => value.data());

    if (team == null) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('Team not found'),
          );
        },
      );
      return;
    }

    await FirebaseFirestore.instance.collection('team_task').doc(id).set({
      'tasks': FieldValue.arrayUnion([
        {"task": newTask, "dueDate": dueDate.toString(), "teamId": id}
      ])
    }, SetOptions(merge: true));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text('Task saved successfully'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[500],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Assign Task'),
      ),
      backgroundColor: Colors.grey[300],
      body: SingleChildScrollView(
        child: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Text(
                  'Assign',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                DropdownButton<String>(
                  value: assignTo,
                  onChanged: (String? newValue) {
                    setState(() {
                      assignTo = newValue!;
                      id =
                          ''; // Reset the ID field whenever the selection changes
                    });
                  },
                  items: assignOptions
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                SizedBox(height: 10),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      id = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText:
                        assignTo == 'Employee' ? 'Employee ID' : 'Team ID',
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  onChanged: (value) {
                    setState(() {
                      newTask = value;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'New Task',
                  ),
                ),
                SizedBox(height: 10),
                InkWell(
                  onTap: () => _selectDueDate(context),
                  child: IgnorePointer(
                    child: TextField(
                      controller: TextEditingController(
                          text: DateFormat('yyyy-MM-dd').format(dueDate)),
                      decoration: InputDecoration(
                        labelText: 'Due Date',
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      saveTasksToFirestore();
                    });
                  },
                  child: Text('Add Task'),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
