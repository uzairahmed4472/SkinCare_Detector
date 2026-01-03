import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Save a test result
  Future<void> saveTestResult(Map<String, dynamic> testResult) async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('test_results')
          .add(testResult);
      print('Test result saved to Firestore successfully');
    } catch (e) {
      print('Error saving test result to Firestore: $e');
      throw e;
    }
  }

  // Get all test results for a user
  Stream<List<Map<String, dynamic>>> getTestResults() {
    String? uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('test_results')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['id'] = doc.id; // Add document ID to the data
        return data;
      }).toList();
    });
  }

  // Delete a specific test result
  Future<void> deleteTestResult(String resultId) async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .collection('test_results')
          .doc(resultId)
          .delete();
      print('Test result deleted successfully');
    } catch (e) {
      print('Error deleting test result: $e');
      throw e;
    }
  }

  // Delete all test results for a user
  Future<void> deleteAllTestResults() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('test_results')
          .get();
      
      for (DocumentSnapshot doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('All test results deleted successfully');
    } catch (e) {
      print('Error deleting all test results: $e');
      throw e;
    }
  }
} 