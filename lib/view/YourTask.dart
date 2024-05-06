import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:fixer_app/helper/util.dart';
import 'package:fixer_app/view/LocationPicker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class YourTask extends StatefulWidget {
  static const String route = 'TaskList';
  const YourTask({Key? key}) : super(key: key);

  @override
  _YourTaskState createState() => _YourTaskState();
}

class _YourTaskState extends State<YourTask> {
  final User? user = FirebaseAuth.instance.currentUser;
  late Map<String, List<Map<String, String>>> tasksByDay = {};
  File? _imageFile;
  String userImageUrl = '';

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

  Future<void> updateTaskCompletionStatus(String taskId, bool? isDone) async {
    var taskDoc =
        FirebaseFirestore.instance.collection('tasks').doc(user?.displayName);

    try {
      var docSnapshot = await taskDoc.get();
      if (docSnapshot.exists) {
        var tasks = List.from(docSnapshot.data()?['tasks'] ?? []);
        var taskIndex = tasks.indexWhere((task) => task['task'] == taskId);
        if (taskIndex != -1) {
          if (isDone!) {
            final supervisor = await FirebaseFirestore.instance
                .collection('users')
                .doc(tasks[taskIndex]['userId'])
                .get()
                .then((value) => value.data());

            sendEmail(supervisor?['email'], 'Task Completed',
                'The task ${tasks[taskIndex]['task']} has been completed by ${user?.displayName}');
          }
          tasks[taskIndex]['isDone'] =
              isDone.toString(); // Update isDone status
          await taskDoc.update({'tasks': tasks});
        }
      }
    } catch (e) {
      print('Error updating task completion status: $e');
    }
  }

  void getTasksFromFirestore() async {
    try {
      var tasksSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(user?.displayName)
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
        title: Text('Your Tasks'),
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
                  'Your Tasks',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value: task['isDone'] == 'true',
                                    onChanged: (bool? newValue) {
                                      setState(() {
                                        task['isDone'] = newValue.toString();
                                        updateTaskCompletionStatus(
                                            task['task']!,
                                            newValue); // Implement this method
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.add_a_photo),
                                    onPressed: () async {
                                      ImagePicker imagePicker = ImagePicker();
                                      XFile? file = await imagePicker.pickImage(
                                        source: ImageSource.camera,
                                      );
                                      if (file != null) {
                                        String imageURL =
                                            await uploadImageToFirebaseStorage(
                                                file, task['task']!);
                                        if (mounted) {
                                          setState(() {
                                            _imageFile = File(file.path);
                                          });
                                        }
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.map_sharp),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LocationPicker(
                                            initialLocation: LatLng(
                                              double.parse(
                                                  task['latitude'] ?? '0'),
                                              double.parse(
                                                  task['longitude'] ?? '0'),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
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
