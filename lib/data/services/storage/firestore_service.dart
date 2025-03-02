import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/task.dart';

// Isolate-compatible data class for task parsing
class TaskParseData {
  final List<Map<String, dynamic>> taskDocs;
  final List<String> docIds;

  TaskParseData(this.taskDocs, this.docIds);
}

// Pure function for parsing tasks in isolate
List<Task> parseTasksIsolate(TaskParseData data) {
  try {
    return List.generate(data.taskDocs.length, (i) {
      try {
        return Task.fromFirestore(data.taskDocs[i], data.docIds[i]);
      } catch (_) {
        return null;
      }
    }).whereType<Task>().toList();
  } catch (_) {
    return <Task>[];
  }
}

class FirestoreService {
  final FirebaseFirestore _firestore;

  // Add caching
  final Map<String, Task> _taskCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, Future<Task?>> _pendingTaskFetches = {};

  // Stream transformers for efficient data processing
  final Map<String,
          StreamTransformer<QuerySnapshot<Map<String, dynamic>>, List<Task>>>
      _streamTransformers = {};

  // Configuration
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int _largeTaskThreshold =
      20; // Number of tasks that warrants isolate processing

  FirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _tasksCollection => _firestore.collection('tasks');
  CollectionReference get _usersCollection => _firestore.collection('users');

  // Clean expired cache entries periodically
  void _cleanCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) > _cacheTtl)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _taskCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  // Reusable stream transformer factory
  StreamTransformer<QuerySnapshot<Map<String, dynamic>>, List<Task>>
      _getTransformer(String cacheKey) {
    if (_streamTransformers.containsKey(cacheKey)) {
      return _streamTransformers[cacheKey]!;
    }

    // Create a transformer that efficiently processes query snapshots
    final transformer = StreamTransformer<QuerySnapshot<Map<String, dynamic>>,
            List<Task>>.fromHandlers(
        handleData: (QuerySnapshot<Map<String, dynamic>> snapshot,
            EventSink<List<Task>> sink) async {
      try {
        if (snapshot.docs.isEmpty) {
          sink.add([]);
          return;
        }

        // Prepare data for parsing
        final taskDocs = snapshot.docs.map((doc) => doc.data()).toList();
        final docIds = snapshot.docs.map((doc) => doc.id).toList();

        List<Task> tasks;

        // Use isolate for large data sets to avoid UI jank
        if (taskDocs.length > _largeTaskThreshold) {
          tasks =
              await compute(parseTasksIsolate, TaskParseData(taskDocs, docIds));
        } else {
          // Parse directly for small data sets
          tasks = List.generate(taskDocs.length, (i) {
            try {
              return Task.fromFirestore(taskDocs[i], docIds[i]);
            } catch (_) {
              return null;
            }
          }).whereType<Task>().toList();
        }

        // Update cache
        final now = DateTime.now();
        for (final task in tasks) {
          _taskCache[task.id] = task;
          _cacheTimestamps[task.id] = now;
        }

        sink.add(tasks);
      } catch (e) {
        // Avoid crashing the stream
        sink.add([]);
      }
    }, handleError: (error, stackTrace, sink) {
      // Return empty list instead of error
      sink.add([]);
    });

    _streamTransformers[cacheKey] = transformer;
    return transformer;
  }

  Stream<List<Task>> getUserTasks(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    // Clean cache periodically
    _cleanCache();

    try {
      final cacheKey = 'user_tasks_$userId';

      // Create query with efficient indexes
      final query = _tasksCollection.where('userId', isEqualTo: userId);

      // Transform the raw Firestore stream
      return query.snapshots().transform(_getTransformer(cacheKey));
    } catch (e) {
      return Stream.value([]);
    }
  }

  Future<void> cancelSubscription(StreamSubscription subscription) async {
    try {
      await subscription.cancel();
    } catch (e) {
      print('Error canceling subscription: $e');
    }
  }

  Stream<List<Task>> getSharedTasks(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]);
    }

    // Clean cache periodically
    _cleanCache();

    try {
      final cacheKey = 'shared_tasks_$userId';

      // Create query with efficient indexes
      final query = _tasksCollection.where('sharedWith', arrayContains: userId);

      // Transform the raw Firestore stream
      return query.snapshots().transform(_getTransformer(cacheKey));
    } catch (e) {
      return Stream.value([]);
    }
  }

  Future<void> saveTask(Task task) async {
    try {
      if (task.id.isEmpty) {
        throw Exception('Cannot save task with empty ID');
      }

      if (task.userId.isEmpty) {
        throw Exception('Cannot save task with empty user ID');
      }

      final taskData = task.toFirestore();

      // Update cache before network operation for responsive UI
      _taskCache[task.id] = task;
      _cacheTimestamps[task.id] = DateTime.now();

      // Perform Firestore operation
      await _tasksCollection.doc(task.id).set(taskData);
    } catch (e) {
      // Remove from cache if save failed
      _taskCache.remove(task.id);
      _cacheTimestamps.remove(task.id);
      throw Exception('Failed to save task to cloud: ${e.toString()}');
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      if (task.id.isEmpty) {
        throw Exception('Cannot update task with empty ID');
      }

      final taskData = task.toFirestore();

      // Update cache before network operation for responsive UI
      _taskCache[task.id] = task;
      _cacheTimestamps[task.id] = DateTime.now();

      // Perform Firestore operation
      await _tasksCollection.doc(task.id).update(taskData);
    } catch (e) {
      throw Exception('Failed to update task in cloud: ${e.toString()}');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      if (taskId.isEmpty) {
        throw Exception('Cannot delete task with empty ID');
      }

      // Remove from cache immediately for responsive UI
      _taskCache.remove(taskId);
      _cacheTimestamps.remove(taskId);

      // Perform Firestore operation
      await _tasksCollection.doc(taskId).delete();
    } catch (e) {
      throw Exception('Failed to delete task from cloud: ${e.toString()}');
    }
  }

  Future<Task?> getTask(String taskId) async {
    try {
      if (taskId.isEmpty) {
        throw Exception('Cannot get task with empty ID');
      }

      // Check cache first
      if (_taskCache.containsKey(taskId)) {
        final cacheTime = _cacheTimestamps[taskId] ??
            DateTime.now().subtract(const Duration(days: 1));
        if (DateTime.now().difference(cacheTime) < _cacheTtl) {
          return _taskCache[taskId];
        }
      }

      // Avoid duplicate fetches for the same task
      if (_pendingTaskFetches.containsKey(taskId)) {
        return await _pendingTaskFetches[taskId]!;
      }

      // Create a completer to track this fetch
      final completer = Completer<Task?>();
      _pendingTaskFetches[taskId] = completer.future;

      try {
        // Perform Firestore operation
        final doc = await _tasksCollection.doc(taskId).get();

        Task? result;
        if (doc.exists && doc.data() != null) {
          result =
              Task.fromFirestore(doc.data()! as Map<String, dynamic>, doc.id);

          // Update cache
          if (result != null) {
            _taskCache[taskId] = result;
            _cacheTimestamps[taskId] = DateTime.now();
          }
        }

        // Complete the pending fetch
        completer.complete(result);
        _pendingTaskFetches.remove(taskId);

        return result;
      } catch (e) {
        completer.completeError(e);
        _pendingTaskFetches.remove(taskId);
        rethrow;
      }
    } catch (e) {
      throw Exception('Failed to retrieve task from cloud: ${e.toString()}');
    }
  }

  Future<void> shareTask(String taskId, String email) async {
    try {
      if (taskId.isEmpty) {
        throw Exception('Cannot share task with empty ID');
      }

      if (email.isEmpty) {
        throw Exception('Cannot share task with empty email');
      }

      final userQuery =
          await _usersCollection.where('email', isEqualTo: email).get();

      if (userQuery.docs.isEmpty) {
        throw Exception('User with email $email not found');
      }

      final userId = userQuery.docs.first.id;

      final taskDoc = await _tasksCollection.doc(taskId).get();
      if (!taskDoc.exists) {
        throw Exception('Task not found');
      }

      // Update local cache if we have the task
      if (_taskCache.containsKey(taskId)) {
        final currentTask = _taskCache[taskId]!;
        final updatedSharedWith = List<String>.from(currentTask.sharedWith)
          ..add(userId);
        if (!updatedSharedWith.contains(userId)) {
          _taskCache[taskId] =
              currentTask.copyWith(sharedWith: updatedSharedWith);
          _cacheTimestamps[taskId] = DateTime.now();
        }
      }

      // Perform Firestore operation
      await _tasksCollection.doc(taskId).update({
        'sharedWith': FieldValue.arrayUnion([userId])
      });
    } catch (e) {
      throw Exception('Failed to share task: ${e.toString()}');
    }
  }

  Future<void> removeSharing(String taskId, String userId) async {
    try {
      if (taskId.isEmpty || userId.isEmpty) {
        throw Exception('Cannot remove sharing with empty IDs');
      }

      // Update local cache if we have the task
      if (_taskCache.containsKey(taskId)) {
        final currentTask = _taskCache[taskId]!;
        final updatedSharedWith = List<String>.from(currentTask.sharedWith)
          ..removeWhere((id) => id == userId);
        _taskCache[taskId] =
            currentTask.copyWith(sharedWith: updatedSharedWith);
        _cacheTimestamps[taskId] = DateTime.now();
      }

      // Perform Firestore operation
      await _tasksCollection.doc(taskId).update({
        'sharedWith': FieldValue.arrayRemove([userId])
      });
    } catch (e) {
      throw Exception('Failed to remove sharing: ${e.toString()}');
    }
  }

  Future<void> saveUserProfile(String userId, String email, String name) async {
    try {
      if (userId.isEmpty) {
        throw Exception('Cannot save profile with empty user ID');
      }

      if (email.isEmpty) {
        throw Exception('Cannot save profile with empty email');
      }

      await _usersCollection.doc(userId).set({
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to save user profile: ${e.toString()}');
    }
  }

  Future<void> updateSharedTask(Task task) async {
    try {
      if (task.id.isEmpty) {
        throw Exception('Cannot update shared task with empty ID');
      }

      // Update cache immediately for responsive UI
      _taskCache[task.id] = task;
      _cacheTimestamps[task.id] = DateTime.now();

      // Only update necessary fields for shared tasks
      Map<String, dynamic> updateData = {
        'isCompleted': task.isCompleted,
        'subtasks': task.subtasks
            .map((s) => {
                  'id': s.id,
                  'title': s.title,
                  'isCompleted': s.isCompleted,
                })
            .toList(),
      };

      // Perform Firestore operation
      await _tasksCollection.doc(task.id).update(updateData);
    } catch (e) {
      throw Exception('Failed to update shared task in cloud: ${e.toString()}');
    }
  }

  // Clean up resources
  void dispose() {
    _taskCache.clear();
    _cacheTimestamps.clear();
    _pendingTaskFetches.clear();
    _streamTransformers.clear();
  }
}
