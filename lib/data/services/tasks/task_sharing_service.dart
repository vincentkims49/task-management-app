import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import '../../models/task.dart';
import '../../repositories/user_repository.dart';

class TaskSharingService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Logger _logger;
  final UserRepository _userRepository;

  TaskSharingService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Logger? logger,
    required UserRepository userRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _logger = logger ?? Logger(),
        _userRepository = userRepository;

  CollectionReference get _tasksCollection => _firestore.collection('tasks');

  Future<void> shareTaskWithUser(String taskId, String email) async {
    try {
      final taskDoc = await _tasksCollection.doc(taskId).get();
      if (!taskDoc.exists || taskDoc.data() == null) {
        throw Exception('Task not found.');
      }

      final task =
          Task.fromFirestore(taskDoc.data()! as Map<String, dynamic>, taskId);

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('You must be signed in to share tasks.');
      }

      if (task.userId != currentUser.uid) {
        throw Exception('You can only share tasks that you own.');
      }

      final userToShare = await _userRepository.getUserByEmail(email);
      if (userToShare == null) {
        throw Exception('User with email $email not found.');
      }

      if (task.sharedWith.contains(userToShare.id)) {
        throw Exception('Task is already shared with this user.');
      }

      String ownerName = task.ownerName;
      if (ownerName.isEmpty) {
        final ownerProfile = await _userRepository.getUserById(task.userId);
        ownerName = ownerProfile?.name ?? 'Unknown';
      }

      final updatedSharedWith = List<String>.from(task.sharedWith)
        ..add(userToShare.id);
      final updatedSharedWithDetails =
          Map<String, String>.from(task.sharedWithDetails)
            ..addAll({userToShare.id: userToShare.name});

      await _tasksCollection.doc(taskId).update({
        'sharedWith': updatedSharedWith,
        'sharedWithDetails': updatedSharedWithDetails,
        'ownerName': ownerName,
      });
    } catch (e) {
      throw Exception('Failed to share task: ${e.toString()}');
    }
  }

  Future<void> removeUserFromSharedTask(String taskId, String userId) async {
    try {
      final taskDoc = await _tasksCollection.doc(taskId).get();
      if (!taskDoc.exists || taskDoc.data() == null) {
        throw Exception('Task not found.');
      }

      final task =
          Task.fromFirestore(taskDoc.data()! as Map<String, dynamic>, taskId);

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('You must be signed in to manage shared tasks.');
      }

      if (task.userId != currentUser.uid) {
        throw Exception('You can only manage sharing of tasks that you own.');
      }

      final updatedSharedWith = List<String>.from(task.sharedWith)
        ..remove(userId);
      final updatedSharedWithDetails =
          Map<String, String>.from(task.sharedWithDetails)..remove(userId);

      await _tasksCollection.doc(taskId).update({
        'sharedWith': updatedSharedWith,
        'sharedWithDetails': updatedSharedWithDetails,
      });
    } catch (e) {
      throw Exception(
          'Failed to remove user from shared task: ${e.toString()}');
    }
  }

  Stream<List<Task>> getSharedTasksForCurrentUser() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _tasksCollection
        .where('sharedWith', arrayContains: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              Task.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  Stream<List<Task>> getTasksSharedByCurrentUser() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _tasksCollection
        .where('userId', isEqualTo: currentUser.uid)
        .where('sharedWith', isNotEqualTo: [])
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Task.fromFirestore(
                  doc.data() as Map<String, dynamic>, doc.id))
              .toList();
        });
  }
}
