import 'package:flutter/material.dart';
import 'package:flutter_application_1/diseases/Vascular%20Lesion.dart';
import 'package:flutter_application_1/diseases/actinic_keratosis.dart';
import 'package:flutter_application_1/diseases/basel.dart';
import 'package:flutter_application_1/diseases/benign_keratosis.dart';
import 'package:flutter_application_1/diseases/cancer.dart';
import 'package:flutter_application_1/diseases/dermatofibroma.dart';
import 'package:flutter_application_1/diseases/melanocytic_nevus.dart';
import 'package:flutter_application_1/diseases/melanoma.dart';
import 'package:flutter_application_1/home.dart';
import 'package:flutter_application_1/skin_test/1-test_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter_application_1/services/firestore_service.dart';

class TestResult {
  final String label;
  final String confidence;
  final String imageBase64;
  final String infoText;
  final String? name;
  final String? email;
  final String? phone;
  final String? affectedArea;
  final String? affectedAreaSize;
  final String? durationInjury;
  final String? itch;
  final String? fever;
  final String? affectedAreaShape;
  final String? affectedAreaColor;
  final String? tissueDamage;
  final DateTime timestamp;
  final String testType;
  final String? id;

  TestResult({
    required this.label,
    required this.confidence,
    required this.imageBase64,
    required this.infoText,
    this.name,
    this.email,
    this.phone,
    this.affectedArea,
    this.affectedAreaSize,
    this.durationInjury,
    this.itch,
    this.fever,
    this.affectedAreaShape,
    this.affectedAreaColor,
    this.tissueDamage,
    required this.timestamp,
    required this.testType,
    this.id,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'imageBase64': imageBase64,
        'infoText': infoText,
        'name': name,
        'email': email,
        'phone': phone,
        'affectedArea': affectedArea,
        'affectedAreaSize': affectedAreaSize,
        'durationInjury': durationInjury,
        'itch': itch,
        'fever': fever,
        'affectedAreaShape': affectedAreaShape,
        'affectedAreaColor': affectedAreaColor,
        'tissueDamage': tissueDamage,
        'timestamp': timestamp.toIso8601String(),
        'testType': testType,
        'id': id,
      };

  factory TestResult.fromJson(Map<String, dynamic> json) => TestResult(
        label: json['label'],
        confidence: json['confidence'],
        imageBase64: json['imageBase64'],
        infoText: json['infoText'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        affectedArea: json['affectedArea'],
        affectedAreaSize: json['affectedAreaSize'],
        durationInjury: json['durationInjury'],
        itch: json['itch'],
        fever: json['fever'],
        affectedAreaShape: json['affectedAreaShape'],
        affectedAreaColor: json['affectedAreaColor'],
        tissueDamage: json['tissueDamage'],
        timestamp: DateTime.parse(json['timestamp']),
        testType: json['testType'] ?? 'quick',
        id: json['id'],
      );
}

class History extends StatefulWidget {
  const History({Key? key}) : super(key: key);

  @override
  State<History> createState() => _HistoryState();
}

class _HistoryState extends State<History> {
  final FirestoreService _firestoreService = FirestoreService();
  List<TestResult> testResults = [];
  List dangerous_lessions = [
    'Melanoma',
    'Melanocytic Nevus',
    'Basal Cell Carcinoma'
  ];
  String? currentUserEmail;

  @override
  void initState() {
    super.initState();
    loadUserEmail();
  }

  Future<void> loadUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserEmail = prefs.getString('email');
    });
    if (currentUserEmail != null) {
      await loadTestResults();
    }
  }

  Future<void> loadTestResults() async {
    if (currentUserEmail == null) {
      print('No user email found when loading test results');
      return;
    }
    
    print('Loading test results for user: $currentUserEmail');
    
    // Listen to Firestore stream
    _firestoreService.getTestResults().listen((results) {
      setState(() {
        testResults = results.map((r) => TestResult.fromJson(r)).toList();
      });
      print('Loaded ${testResults.length} test results');
    }, onError: (e) {
      print('Error loading test results: $e');
    });
  }

  Future<void> deleteTestResult(int index) async {
    if (currentUserEmail == null) return;
    
    try {
      // Get the result to be deleted
      TestResult resultToDelete = testResults[index];
      if (resultToDelete.id == null) {
        print('Error: Test result has no ID');
        return;
      }

      // Delete from Firestore
      await _firestoreService.deleteTestResult(resultToDelete.id!);
      
      // The UI will automatically update through the stream listener
      print('Deleted test result with ID: ${resultToDelete.id}');
    } catch (e) {
      print('Error deleting test result: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete test result'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> deleteAllResults() async {
    if (currentUserEmail == null) return;
    
    try {
      await _firestoreService.deleteAllTestResults();
      setState(() {
        testResults.clear();
      });
    } catch (e) {
      print('Error deleting all test results: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 16, 170, 226),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color.fromARGB(255, 16, 170, 226),
                Color.fromARGB(255, 87, 179, 212),
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_outlined, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Home()),
            );
          },
        ),
        title: Text(
          'History',
          style: TextStyle(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.home_sharp, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Home()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(146, 147, 226, 255),
              Color.fromARGB(255, 227, 245, 255)
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: currentUserEmail == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_circle, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Please log in to view your test history',
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              )
            : testResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/nodata1.png', height: 200),
                        SizedBox(height: 20),
                        Text(
                          'No test results found',
                          style: TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: testResults.length,
                    itemBuilder: (context, index) {
                      final result = testResults[index];
                      return Card(
                        margin: EdgeInsets.all(8),
                        child: ExpansionTile(
                          title: Text(
                            result.label,
                            style: TextStyle(
                              fontSize: 20,
                              color: dangerous_lessions.contains(result.label)
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confidence: ${result.confidence}%\nDate: ${result.timestamp.toString().split('.')[0]}',
                              ),
                              Text(
                                'Test Type: ${result.testType.toUpperCase()}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: result.testType == 'advanced'
                                      ? Colors.blue
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Container(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (result.imageBase64 != 'Not Selected')
                                    Container(
                                      height: 200,
                                      width: double.infinity,
                                      child: Image.memory(
                                        base64.decode(result.imageBase64),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  SizedBox(height: 16),
                                  if (result.name != null)
                                    Text('Name: ${result.name}'),
                                  if (result.email != null)
                                    Text('Email: ${result.email}'),
                                  if (result.phone != null)
                                    Text('Phone: ${result.phone}'),
                                  if (result.affectedArea != null)
                                    Text('Affected Area: ${result.affectedArea}'),
                                  if (result.affectedAreaSize != null)
                                    Text('Size: ${result.affectedAreaSize}'),
                                  if (result.durationInjury != null)
                                    Text('Duration: ${result.durationInjury}'),
                                  if (result.itch != null)
                                    Text('Itch: ${result.itch}'),
                                  if (result.fever != null)
                                    Text('Fever: ${result.fever}'),
                                  if (result.affectedAreaShape != null)
                                    Text('Shape: ${result.affectedAreaShape}'),
                                  if (result.affectedAreaColor != null)
                                    Text('Color: ${result.affectedAreaColor}'),
                                  if (result.tissueDamage != null)
                                    Text('Tissue Damage: ${result.tissueDamage}'),
                                  SizedBox(height: 16),
                                  Text(result.infoText),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          // Navigate to disease detail page
                                          switch (result.label) {
                                            case 'Melanoma':
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) => Melanoma()),
                                              );
                                              break;
                                            case 'Basal Cell Carcinoma':
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) => Basel()),
                                              );
                                              break;
                                            // Add other cases as needed
                                          }
                                        },
                                        child: Text('View Details'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: Text("Delete Test Result"),
                                                content: Text(
                                                    "Are you sure you want to delete this test result?"),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                    },
                                                    child: Text("Cancel"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      deleteTestResult(index);
                                                      Navigator.of(context).pop();
                                                    },
                                                    child: Text("Delete"),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          primary: Colors.red,
                                        ),
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: testResults.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text("Delete All Results"),
                      content: Text(
                          "Are you sure you want to delete all test results?"),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () {
                            deleteAllResults();
                            Navigator.of(context).pop();
                          },
                          child: Text("Delete All"),
                        ),
                      ],
                    );
                  },
                );
              },
              backgroundColor: Colors.red,
              child: Icon(Icons.delete_sweep),
            )
          : null,
    );
  }
}
