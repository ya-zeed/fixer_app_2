import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class EmployeeTask extends StatefulWidget {
  static const String route = 'EmployeeTask';
  const EmployeeTask({Key? key}) : super(key: key);

  @override
  _EmployeeTaskState createState() => _EmployeeTaskState();
}

class _EmployeeTaskState extends State<EmployeeTask> {
  final User? user = FirebaseAuth.instance.currentUser;
  late Map<String, List<Map<String, String>>> tasksByDay = {};
  File? _imageFile;
  String userImageUrl = '';

  final TextEditingController _employeeIdController = TextEditingController();
  String? _employeeId;

  @override
  void dispose() {
    // Dispose the controller when the widget is removed from the widget tree
    _employeeIdController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    getTasksFromFirestore();
  }

  Future<void> saveImageToFirestore(String imageUrl, String taskName) async {
    var userDisplayName = user?.displayName;
    if (userDisplayName == null) {
      print('User display name is null');
      return;
    }

    var taskDoc =
        FirebaseFirestore.instance.collection('tasks').doc(userDisplayName);

    try {
      var docSnapshot = await taskDoc.get();
      if (docSnapshot.exists) {
        var tasks = List.from(docSnapshot.data()?['tasks'] ?? []);
        for (var task in tasks) {
          if (task['task'] == taskName) {
            task['image'] = imageUrl;
            break;
          }
        }
        await taskDoc.update({'tasks': tasks});
      } else {
        print('Document does not exist');
      }
    } catch (e) {
      print('Error updating document: $e');
    }
  }

  Future<String> getImageFromFirestore(String task) async {
    var imageSnapshot;

    var taskDoc =
        FirebaseFirestore.instance.collection('tasks').doc(user?.displayName);

    var docSnapshot = await taskDoc.get();
    if (docSnapshot.exists) {
      var tasks = List.from(docSnapshot.data()?['tasks'] ?? []);
      for (var task in tasks) {
        if (task['task'] == task) {
          imageSnapshot = task['image'];
          break;
        }
      }

      if (imageSnapshot.exists) {
        var imageMap = imageSnapshot.data()?['picture'];
        if (imageMap != null && imageMap is Map<String, dynamic>) {
          String imageUrl = imageMap['image'].toString();
          if (imageUrl != null) {
            print(imageUrl);
            setState(() {
              userImageUrl = imageUrl;
            });
          }
        }
      }
    }

    return imageSnapshot;
  }

  void getTasksFromFirestore() async {
    if (_employeeId == null || _employeeId!.isEmpty) {
      Dialog(
        child: Container(
          child: Text('Please enter an employee ID'),
        ),
      );
      return;
    }

    try {
      var tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(_employeeId)
          .get();

      if (tasksSnapshot.exists) {
        var fetchedTasks = (tasksSnapshot.data()?['tasks'] ?? [])
            .map<Map<String, String>>((task) {
          return Map<String, String>.from(task as Map);
        }).toList();

        var groupedTasks = groupTasksByDay(fetchedTasks);
        setState(() {
          tasksByDay = groupedTasks;
        });
      }
    } catch (e) {
      print('Error retrieving tasks from Firestore: $e');
    }
  }

  Map<String, List<Map<String, String>>> groupTasksByDay(
      List<Map<String, String>> tasks) {
    Map<String, List<Map<String, String>>> grouped = {};
    for (var task in tasks) {
      String dayOfWeek =
          DateFormat('EEEE').format(DateTime.parse(task['dueDate']!));
      if (!grouped.containsKey(dayOfWeek)) {
        grouped[dayOfWeek] = [];
      }
      grouped[dayOfWeek]!.add(task);
    }
    return grouped;
  }

  Future<String> uploadImageToFirebaseStorage(XFile file, String task) async {
    File imageFile = File(file.path);
    String fileName = '${DateTime.now().millisecondsSinceEpoch}.png';

    // Convert the image file to PNG format
    List<int> imageBytes = await imageFile.readAsBytes();
    File pngFile = await File('${imageFile.path}.png').writeAsBytes(imageBytes);

    // Upload the PNG file to Firebase Storage
    firebase_storage.Reference ref =
        firebase_storage.FirebaseStorage.instance.ref().child(fileName);
    firebase_storage.UploadTask uploadTask = ref.putFile(pngFile);
    firebase_storage.TaskSnapshot taskSnapshot = await uploadTask;

    // Get the download URL of the uploaded PNG file
    String downloadURL = await taskSnapshot.ref.getDownloadURL();
    saveImageToFirestore(downloadURL, task);

    // Delete the temporary PNG file
    await pngFile.delete();

    return downloadURL;
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
        title: Text('Employee Tasks'),
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
                // New TextField for employee ID
                TextField(
                  controller: _employeeIdController,
                  decoration: InputDecoration(
                    labelText: 'Employee ID',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _employeeId = value;
                  },
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _employeeId = _employeeIdController.text;
                      getTasksFromFirestore();
                    });
                  },
                  child: Text('Search Tasks'),
                ),
                SizedBox(height: 20),
                ...tasksByDay.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key, // Day of the week
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      ...entry.value.map((task) => Card(
                            child: ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('From: ${task['userId']}'),
                                  Text('Task: ${task['task']}'),
                                ],
                              ),
                              subtitle: Text(
                                  'Due: ${DateFormat('yyyy-MM-DD').format(DateTime.parse(task['dueDate']!))}'),
                              leading: task['image'] != null
                                  ? GestureDetector(
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return Dialog(
                                              child: Container(
                                                width: double.infinity,
                                                child: Image.network(
                                                    task['image'] ?? '',
                                                    fit: BoxFit.cover),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: CircleAvatar(
                                        backgroundImage:
                                            NetworkImage(task['image'] ?? ''),
                                      ),
                                    )
                                  : null,
                            ),
                          )),
                    ],
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
