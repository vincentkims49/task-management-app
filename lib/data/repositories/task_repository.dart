import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/subtask.dart';
import '../services/storage/local_storage_service.dart';
import '../services/storage/firestore_service.dart';
import '../services/network/connectivity_service.dart';

// Data class for sorting in isolate
class SortParams {
  final List<Task> tasks;
  final String sortBy;
  final bool ascending;

  SortParams(this.tasks, this.sortBy, this.ascending);
}

// Pure function for isolate computation
List<Task> sortTasksIsolate(SortParams params) {
  final tasks = params.tasks;
  final sortBy = params.sortBy;
  final ascending = params.ascending;

  List<Task> sortedTasks = List.from(tasks);

  switch (sortBy) {
    case 'title':
      sortedTasks.sort((a, b) =>
          ascending ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
      break;
    case 'dueDate':
      sortedTasks.sort((a, b) {
        return ascending
            ? a.dueDate.compareTo(b.dueDate)
            : b.dueDate.compareTo(a.dueDate);
      });
      break;
    case 'priority':
      sortedTasks.sort((a, b) => ascending
          ? a.priority.index.compareTo(b.priority.index)
          : b.priority.index.compareTo(a.priority.index));
      break;
    case 'created':
      sortedTasks.sort((a, b) => ascending
          ? a.createdAt.compareTo(b.createdAt)
          : b.createdAt.compareTo(a.createdAt));
      break;
    case 'completed':
      sortedTasks.sort((a, b) {
        final completionComparison = a.isCompleted == b.isCompleted
            ? 0
            : (a.isCompleted ? (ascending ? 1 : -1) : (ascending ? -1 : 1));

        return completionComparison != 0
            ? completionComparison
            : a.title.compareTo(b.title);
      });
      break;
    default:
      sortedTasks.sort((a, b) =>
          ascending ? a.title.compareTo(b.title) : b.title.compareTo(a.title));
  }

  return sortedTasks;
}

class TaskRepository {
  final LocalStorageService _storageService;
  final FirestoreService _firestoreService;
  final ConnectivityService _connectivityService;
  final _taskStreamController = StreamController<List<Task>>.broadcast();

  StreamSubscription<List<Task>>? _firestoreSubscription;
  StreamSubscription<List<Task>>? _sharedTasksSubscription;

  // Cache for tasks
  List<Task> _ownedTasks = [];
  List<Task> _sharedTasks = [];

  // Add a throttle timer
  Timer? _notificationThrottle;
  static const _streamThrottleDuration = Duration(milliseconds: 300);
  DateTime _lastStreamUpdate = DateTime.now();

  // Add memory caches
  final Map<String, Task> _taskCache = {}; // Cache for individual tasks
  final Map<String, List<Task>> _queryCacheByUserId =
      {}; // Cache for query results

  final List<Future<void> Function()> _pendingOperations = [];
  bool _processingQueue = false;
  bool isSigningOut = false;

  TaskRepository({
    required LocalStorageService storageService,
    required FirestoreService firestoreService,
    required ConnectivityService connectivityService,
  })  : _storageService = storageService,
        _firestoreService = firestoreService,
        _connectivityService = connectivityService {
    _connectivityService.connectionStatus.listen((isConnected) {
      if (isConnected) {
        _processPendingOperations();
      }
    });
  }

  Stream<List<Task>> get tasks => _taskStreamController.stream;

  Future<void> init(String userId) async {
    if (isSigningOut) {
      print('TaskRepository: Ignoring init request during sign-out');
      return;
    }

    try {
      if (_firestoreSubscription != null) {
        await _firestoreService.cancelSubscription(_firestoreSubscription!);
        _firestoreSubscription = null;
      }

      if (_sharedTasksSubscription != null) {
        await _firestoreService.cancelSubscription(_sharedTasksSubscription!);
        _sharedTasksSubscription = null;
      }
    } catch (e) {
      print('Error cancelling old subscriptions: $e');
    }

    _ownedTasks = [];
    _sharedTasks = [];

    // Clear caches on initialization
    _clearCaches();

    // Use a delay to prevent blocking UI during initialization
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      // Load from local first for immediate UI response
      final userTasks = await _storageService.getTasksByUserId(userId);
      _cacheTasks(userTasks);
      if (!_taskStreamController.isClosed) {
        _taskStreamController.add(userTasks);
      }

      // Setup Firebase listeners
      _firestoreSubscription = _firestoreService.getUserTasks(userId).listen(
        (firebaseTasks) async {
          if (!isSigningOut) {
            _ownedTasks = firebaseTasks;
            _cacheTasks(firebaseTasks);

            // Throttle updates to prevent excessive refreshes
            _throttledRefreshAllTasks(userId);
          }
        },
        onError: (error) {
          print('Error in getUserTasks stream: $error');

          if (error.toString().contains('PERMISSION_DENIED') && !isSigningOut) {
            _taskStreamController.add([]);
          }
        },
        cancelOnError: false,
      );

      _sharedTasksSubscription =
          _firestoreService.getSharedTasks(userId).listen(
        (sharedTasks) async {
          if (!isSigningOut) {
            _sharedTasks = sharedTasks;
            _cacheTasks(sharedTasks);

            // Throttle updates to prevent excessive refreshes
            _throttledRefreshAllTasks(userId);
          }
        },
        onError: (error) {
          print('Error in getSharedTasks stream: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('Error initializing TaskRepository: $e');
    }
  }

  // Add task caching
  void _cacheTasks(List<Task> tasks) {
    for (final task in tasks) {
      _taskCache[task.id] = task;
    }
  }

  // Clear all caches
  void _clearCaches() {
    _taskCache.clear();
    _queryCacheByUserId.clear();
  }

  // Throttle updates to avoid excessive UI refreshes
  void _throttledRefreshAllTasks(String userId) {
    // Cancel any pending update
    _notificationThrottle?.cancel();

    // Check if we should throttle based on time
    final now = DateTime.now();
    if (now.difference(_lastStreamUpdate) < _streamThrottleDuration) {
      // Schedule a delayed update instead of immediate
      _notificationThrottle = Timer(_streamThrottleDuration, () {
        _saveAndRefreshAllTasks(userId);
      });
      return;
    }

    // Update now
    _lastStreamUpdate = now;
    _saveAndRefreshAllTasks(userId);
  }

  Future<void> _saveAndRefreshAllTasks(String userId) async {
    try {
      final allFirebaseTasks = [..._ownedTasks, ..._sharedTasks];

      if (allFirebaseTasks.isNotEmpty) {
        // Use a microtask to not block the UI thread
        await Future.microtask(
            () => _storageService.saveAllTasks(allFirebaseTasks));
      }

      final allTasks = await _getAllTasksIncludingShared(userId);

      if (!_taskStreamController.isClosed) {
        _taskStreamController.add(allTasks);
      }
    } catch (e) {
      print('Error saving and refreshing all tasks: $e');
    }
  }

  Future<void> reset() async {
    print('TaskRepository: Starting reset process...');

    isSigningOut = true;

    try {
      if (_firestoreSubscription != null) {
        try {
          await _firestoreSubscription!.cancel();
          print('TaskRepository: Successfully cancelled firestoreSubscription');
        } catch (e) {
          print('TaskRepository: Error cancelling firestoreSubscription: $e');
        } finally {
          _firestoreSubscription = null;
        }
      }

      if (_sharedTasksSubscription != null) {
        try {
          await _sharedTasksSubscription!.cancel();
          print(
              'TaskRepository: Successfully cancelled sharedTasksSubscription');
        } catch (e) {
          print('TaskRepository: Error cancelling sharedTasksSubscription: $e');
        } finally {
          _sharedTasksSubscription = null;
        }
      }

      _ownedTasks = [];
      _sharedTasks = [];
      _clearCaches();

      print('TaskRepository: Clearing pending operations...');
      _pendingOperations.clear();
      _processingQueue = false;

      print('TaskRepository: Resetting task stream...');
      if (!_taskStreamController.isClosed) {
        _taskStreamController.add([]);
      }

      print('TaskRepository: Clearing local storage...');
      try {
        await _storageService.clearAllTasks();
        print('TaskRepository: Successfully cleared local storage');
      } catch (e) {
        print('TaskRepository: Error clearing local storage: $e');

        try {
          final tasks = await _storageService.getAllTasks();
          for (final task in tasks) {
            try {
              await _storageService.deleteTask(task.id);
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (e) {
      print('TaskRepository: Unexpected error during reset: $e');
    } finally {
      isSigningOut = false;
      print('TaskRepository: Reset completed');
    }
  }

  // Move sorting to compute for better performance
  Future<List<Task>> _sortTasks(List<Task> tasks,
      {String sortBy = 'title', bool ascending = true}) async {
    if (tasks.length < 50) {
      // For small lists, sort directly without isolate overhead
      return sortTasksIsolate(SortParams(tasks, sortBy, ascending));
    } else {
      // For larger lists, use compute to offload sorting
      return await compute(
          sortTasksIsolate, SortParams(tasks, sortBy, ascending));
    }
  }

  Future<void> dispose() async {
    _notificationThrottle?.cancel();
    await _firestoreSubscription?.cancel();
    await _sharedTasksSubscription?.cancel();

    _firestoreSubscription = null;
    _sharedTasksSubscription = null;

    _ownedTasks = [];
    _sharedTasks = [];
    _clearCaches();

    _taskStreamController.add([]);
  }

  Future<void> _processPendingOperations() async {
    if (_processingQueue || _pendingOperations.isEmpty) return;

    _processingQueue = true;

    try {
      final operations = List<Future<void> Function()>.from(_pendingOperations);
      _pendingOperations.clear();

      // Process in batches to prevent UI blocking
      const batchSize = 5;

      for (int i = 0; i < operations.length; i += batchSize) {
        final end = (i + batchSize < operations.length)
            ? i + batchSize
            : operations.length;
        final batch = operations.sublist(i, end);

        for (final operation in batch) {
          try {
            await operation();
          } catch (e) {
            _pendingOperations.add(operation);
          }
        }

        // Give UI thread a chance to breathe
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } finally {
      _processingQueue = false;

      if (_pendingOperations.isNotEmpty) {
        Future.delayed(const Duration(minutes: 1), _processPendingOperations);
      }
    }
  }

  Future<List<Task>> _getAllTasksIncludingShared(String userId,
      {String sortBy = 'title'}) async {
    // Check cache first
    final cacheKey = '${userId}_all_$sortBy';
    if (_queryCacheByUserId.containsKey(cacheKey)) {
      return _queryCacheByUserId[cacheKey]!;
    }

    final ownedTasks = await _storageService.getTasksByUserId(userId);

    final sharedTasks = (await _storageService.getAllTasks())
        .where(
            (task) => task.userId != userId && task.sharedWith.contains(userId))
        .toList();

    final allTasks = [...ownedTasks, ...sharedTasks];
    final sortedTasks = await _sortTasks(allTasks, sortBy: sortBy);

    // Cache the results
    _queryCacheByUserId[cacheKey] = sortedTasks;

    return sortedTasks;
  }

  Future<String> createTask({
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required String userId,
    String? ownerName,
    List<Subtask> subtasks = const [],
  }) async {
    final taskOwnerName = ownerName ?? 'User';

    final task = Task.create(
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      userId: userId,
      subtasks: subtasks,
      ownerName: taskOwnerName,
    );

    // Update local cache immediately
    _taskCache[task.id] = task;
    _queryCacheByUserId.clear(); // Clear query cache since we added a task

    // Save to storage
    await _storageService.saveTask(task);

    final isConnected = await _connectivityService.isConnected();
    if (isConnected) {
      try {
        await _firestoreService.saveTask(task);
      } catch (e) {
        _pendingOperations.add(() => _firestoreService.saveTask(task));
      }
    } else {
      _pendingOperations.add(() => _firestoreService.saveTask(task));
    }

    // Don't wait for this to complete to return task ID
    _refreshTasks(userId);

    return task.id;
  }

  Future<Task?> getTask(String taskId) async {
    // Check in-memory cache first
    if (_taskCache.containsKey(taskId)) {
      return _taskCache[taskId];
    }

    // Check local storage
    Task? task = await _storageService.getTask(taskId);

    // If not found locally and online, fetch from Firebase
    if (task == null && await _connectivityService.isConnected()) {
      task = await _firestoreService.getTask(taskId);

      if (task != null) {
        await _storageService.saveTask(task);
        // Update cache
        _taskCache[taskId] = task;
      }
    }

    return task;
  }

  Future<List<Task>> getAllTasks(String userId) async {
    return await _getAllTasksIncludingShared(userId);
  }

  Future<void> updateTask(Task task, {String? currentUserId}) async {
    final userId = currentUserId ?? task.userId;

    final isSharedTask =
        task.userId != userId && task.sharedWith.contains(userId);

    try {
      print(
          'TaskRepository: Updating task: ${task.id} (shared: $isSharedTask)');

      // Update cache immediately for responsive UI
      _taskCache[task.id] = task;
      _queryCacheByUserId.clear(); // Clear query caches

      // Update storage
      await _storageService.saveTask(task);

      // Perform the update in Firebase if connected
      final isConnected = await _connectivityService.isConnected();
      if (isConnected) {
        try {
          if (isSharedTask) {
            await _firestoreService.updateSharedTask(task);
          } else {
            await _firestoreService.updateTask(task);
          }
          print('TaskRepository: Task updated successfully in Firestore');
        } catch (e) {
          print('Error updating task in Firestore: $e');

          if (isSharedTask) {
            _pendingOperations
                .add(() => _firestoreService.updateSharedTask(task));
          } else {
            _pendingOperations.add(() => _firestoreService.updateTask(task));
          }
        }
      } else {
        if (isSharedTask) {
          _pendingOperations
              .add(() => _firestoreService.updateSharedTask(task));
        } else {
          _pendingOperations.add(() => _firestoreService.updateTask(task));
        }
      }
    } catch (e) {
      print('Error in updateTask: $e');
      rethrow;
    }
  }

  Future<void> clearLocalCache() async {
    try {
      print('TaskRepository: Clearing task cache');

      _ownedTasks = [];
      _sharedTasks = [];
      _clearCaches();

      _pendingOperations.clear();
      _processingQueue = false;

      print('TaskRepository: Task cache cleared');
    } catch (e) {
      print('Error clearing task cache: $e');
    }
  }

  Future<void> deleteTask(String taskId, String userId) async {
    // Remove from cache
    _taskCache.remove(taskId);
    _queryCacheByUserId.clear();

    await _storageService.deleteTask(taskId);

    final isConnected = await _connectivityService.isConnected();
    if (isConnected) {
      try {
        await _firestoreService.deleteTask(taskId);
      } catch (e) {
        _pendingOperations.add(() => _firestoreService.deleteTask(taskId));
      }
    } else {
      _pendingOperations.add(() => _firestoreService.deleteTask(taskId));
    }

    await _refreshTasks(userId);
  }

  Future<void> shareTask(String taskId, String email, String userId) async {
    final task = await getTask(taskId);
    if (task == null) {
      throw Exception('Task not found');
    }

    final isConnected = await _connectivityService.isConnected();
    if (isConnected) {
      try {
        await _firestoreService.shareTask(taskId, email);
      } catch (e) {
        throw Exception('Failed to share task: $e');
      }
    } else {
      throw Exception('Cannot share task while offline');
    }
  }

  Future<void> toggleTaskCompletion(String taskId, String userId,
      {String? currentUserId}) async {
    final task = await getTask(taskId);
    if (task != null) {
      final updatedTask = task.copyWith(isCompleted: !task.isCompleted);

      // Update cache immediately for responsive UI
      _taskCache[taskId] = updatedTask;

      await updateTask(updatedTask, currentUserId: currentUserId ?? userId);
    }
  }

  Future<void> addSubtask(String taskId, String subtaskTitle, String userId,
      {String? currentUserId}) async {
    final task = await getTask(taskId);
    if (task != null) {
      final newSubtask = Subtask.create(title: subtaskTitle);
      final updatedSubtasks = List<Subtask>.from(task.subtasks)
        ..add(newSubtask);
      final updatedTask = task.copyWith(subtasks: updatedSubtasks);

      // Update cache immediately
      _taskCache[taskId] = updatedTask;

      await updateTask(updatedTask, currentUserId: currentUserId ?? userId);
    }
  }

  Future<void> updateSubtask(String taskId, Subtask subtask, String userId,
      {String? currentUserId}) async {
    final task = await getTask(taskId);
    if (task != null) {
      final updatedSubtasks = task.subtasks.map((s) {
        return s.id == subtask.id ? subtask : s;
      }).toList();
      final updatedTask = task.copyWith(subtasks: updatedSubtasks);

      // Update cache immediately
      _taskCache[taskId] = updatedTask;

      await updateTask(updatedTask, currentUserId: currentUserId ?? userId);
    }
  }

  Future<void> toggleSubtaskCompletion(
      String taskId, String subtaskId, String userId,
      {String? currentUserId}) async {
    final task = await getTask(taskId);
    if (task != null) {
      final updatedSubtasks = task.subtasks.map((subtask) {
        if (subtask.id == subtaskId) {
          return subtask.copyWith(isCompleted: !subtask.isCompleted);
        }
        return subtask;
      }).toList();

      final updatedTask = task.copyWith(subtasks: updatedSubtasks);

      // Update cache immediately
      _taskCache[taskId] = updatedTask;

      await updateTask(updatedTask, currentUserId: currentUserId ?? userId);
    }
  }

  Future<void> deleteSubtask(String taskId, String subtaskId, String userId,
      {String? currentUserId}) async {
    final task = await getTask(taskId);
    if (task != null) {
      final updatedSubtasks =
          task.subtasks.where((s) => s.id != subtaskId).toList();
      final updatedTask = task.copyWith(subtasks: updatedSubtasks);

      // Update cache immediately
      _taskCache[taskId] = updatedTask;

      await updateTask(updatedTask, currentUserId: currentUserId ?? userId);
    }
  }

  Future<List<Task>> getTasksByCompletionStatus(
      String userId, bool isCompleted) async {
    // Check cache first
    final cacheKey = '${userId}_completion_$isCompleted';
    if (_queryCacheByUserId.containsKey(cacheKey)) {
      return _queryCacheByUserId[cacheKey]!;
    }

    final tasks = await getAllTasks(userId);
    final filteredTasks =
        tasks.where((task) => task.isCompleted == isCompleted).toList();

    // Cache results
    _queryCacheByUserId[cacheKey] = filteredTasks;

    return filteredTasks;
  }

  Future<List<Task>> getTasksDueToday(String userId) async {
    // Check cache first
    final cacheKey = '${userId}_due_today';
    if (_queryCacheByUserId.containsKey(cacheKey)) {
      return _queryCacheByUserId[cacheKey]!;
    }

    final tasks = await getAllTasks(userId);
    final filteredTasks = tasks.where((task) => task.isDueToday()).toList();

    // Cache results
    _queryCacheByUserId[cacheKey] = filteredTasks;

    return filteredTasks;
  }

  Future<List<Task>> getOverdueTasks(String userId) async {
    // Check cache first
    final cacheKey = '${userId}_overdue';
    if (_queryCacheByUserId.containsKey(cacheKey)) {
      return _queryCacheByUserId[cacheKey]!;
    }

    final tasks = await getAllTasks(userId);
    final filteredTasks =
        tasks.where((task) => task.isOverdue() && !task.isCompleted).toList();

    // Cache results
    _queryCacheByUserId[cacheKey] = filteredTasks;

    return filteredTasks;
  }

  Future<List<Task>> getTasksByPriority(
      String userId, TaskPriority priority) async {
    // Check cache first
    final cacheKey = '${userId}_priority_${priority.index}';
    if (_queryCacheByUserId.containsKey(cacheKey)) {
      return _queryCacheByUserId[cacheKey]!;
    }

    final tasks = await getAllTasks(userId);
    final filteredTasks =
        tasks.where((task) => task.priority == priority).toList();

    // Cache results
    _queryCacheByUserId[cacheKey] = filteredTasks;

    return filteredTasks;
  }

  Future<List<Task>> searchTasks(String userId, String query) async {
    if (query.isEmpty) return await getAllTasks(userId);

    // Check cache first
    final cacheKey = '${userId}_search_$query';
    if (_queryCacheByUserId.containsKey(cacheKey)) {
      return _queryCacheByUserId[cacheKey]!;
    }

    final tasks = await getAllTasks(userId);
    final lowerQuery = query.toLowerCase();

    final filteredTasks = tasks.where((task) {
      return task.title.toLowerCase().contains(lowerQuery) ||
          task.description.toLowerCase().contains(lowerQuery);
    }).toList();

    // Cache results if query is substantial (avoid caching single letter searches)
    if (query.length > 2) {
      _queryCacheByUserId[cacheKey] = filteredTasks;
    }

    return filteredTasks;
  }

  Future<List<Task>> forceLoadAllTasks(String userId) async {
    try {
      // Clear caches for a true force reload
      _queryCacheByUserId.clear();

      final ownedTasks = await _storageService.getTasksByUserId(userId);

      final allTasks = await _storageService.getAllTasks();
      final sharedTasks = allTasks
          .where((task) =>
              task.userId != userId && task.sharedWith.contains(userId))
          .toList();

      final combinedTasks = [...ownedTasks, ...sharedTasks];

      // Cache these tasks
      _cacheTasks(combinedTasks);

      return await _sortTasks(combinedTasks);
    } catch (e) {
      print('Error in forceLoadAllTasks: $e');
      return [];
    }
  }

  Future<void> clearAllTasks(String userId) async {
    final tasks = await _storageService.getTasksByUserId(userId);

    for (final task in tasks) {
      await deleteTask(task.id, userId);
    }

    // Clear all caches
    _clearCaches();
  }

  Future<void> _refreshTasks(String userId) async {
    await _saveAndRefreshAllTasks(userId);
  }
}
