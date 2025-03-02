import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/subtask.dart';
import '../../data/models/task.dart';
import '../../data/models/task_filter.dart';
import '../../data/repositories/task_repository.dart';
import '../../utils/notification_helper.dart';
import 'task_event.dart';
import 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final TaskRepository _taskRepository;
  late StreamSubscription<List<Task>> _tasksSubscription;

  bool _isActive = true;

  bool _isFiltering = false;

  Timer? _filterDebouncer;

  TaskBloc({required TaskRepository taskRepository})
      : _taskRepository = taskRepository,
        super(const TaskState()) {
    on<LoadTasks>(_onLoadTasks);
    on<AddTask>(_onAddTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
    on<ToggleTaskCompletion>(_onToggleTaskCompletion);
    on<AddSubtask>(_onAddSubtask);
    on<UpdateSubtask>(_onUpdateSubtask);
    on<ToggleSubtaskCompletion>(_onToggleSubtaskCompletion);
    on<DeleteSubtask>(_onDeleteSubtask);
    on<FilterTasks>(_onFilterTasks);
    on<ResetTasks>(_onResetTasks);
    on<ResetTaskBloc>(_onResetTaskBloc);
    on<ForceRefreshTasks>(_onForceRefreshTasks);

    _tasksSubscription = _taskRepository.tasks.listen(
      (tasks) {
        try {
          if (!_isActive) {
            return;
          }

          String userId = '';
          if (state.tasks.isNotEmpty) {
            userId = state.tasks.first.userId;
          } else if (tasks.isNotEmpty) {
            userId = tasks.first.userId;
          }

          if (userId.isNotEmpty) {
            _filterDebouncer?.cancel();
            _filterDebouncer = Timer(const Duration(milliseconds: 300), () {
              if (_isActive) {
                add(FilterTasks(
                  userId: userId,
                  filter: state.activeFilter,
                  priorityFilter: state.priorityFilter,
                  searchQuery: state.searchQuery,
                ));
              }
            });
          } else {
            if (_isActive) {
              emit(state.copyWith(
                status: TaskStatus.success,
                tasks: tasks,
                filteredTasks: tasks,
              ));
            }
          }
        } catch (e, stackTrace) {
          if (_isActive) {
            emit(state.copyWith(
                status: TaskStatus.failure,
                errorMessage: 'Error updating tasks: ${e.toString()}'));
          }
        }
      },
      onError: (error, stackTrace) {
        if (_isActive) {
          emit(state.copyWith(
              status: TaskStatus.failure,
              errorMessage: 'Task stream error: ${error.toString()}'));
        }
      },
    );
  }
  Future<void> reactivate(String userId) async {
    print('TaskBloc reactivation started for user: $userId');

    if (!_isActive) {
      _isActive = true;
      print('TaskBloc set to active state');

      emit(const TaskState(status: TaskStatus.loading));

      try {
        await _taskRepository.clearLocalCache();
        print('Local task cache cleared');

        await _taskRepository.init(userId);
        print('Task repository initialized for user: $userId');

        final tasks = await _taskRepository.getAllTasks(userId);
        print('Fetched ${tasks.length} tasks for user');

        for (final task in tasks) {
          if (!task.isCompleted) {
            try {
              await NotificationHelper.scheduleTaskReminder(task);
            } catch (e) {
              print('Error scheduling reminder: $e');
            }
          }
        }

        if (_isActive) {
          emit(state.copyWith(
            status: TaskStatus.success,
            tasks: tasks,
            filteredTasks: tasks,
          ));
          print('TaskBloc state updated with ${tasks.length} tasks');
        }

        _tasksSubscription.cancel().then((_) {
          _tasksSubscription = _taskRepository.tasks.listen(
            (tasks) {
              try {
                if (!_isActive) return;

                String userId = '';
                if (state.tasks.isNotEmpty) {
                  userId = state.tasks.first.userId;
                } else if (tasks.isNotEmpty) {
                  userId = tasks.first.userId;
                }

                if (userId.isNotEmpty) {
                  _filterDebouncer?.cancel();
                  _filterDebouncer =
                      Timer(const Duration(milliseconds: 300), () {
                    if (_isActive) {
                      add(FilterTasks(
                        userId: userId,
                        filter: state.activeFilter,
                        priorityFilter: state.priorityFilter,
                        searchQuery: state.searchQuery,
                      ));
                    }
                  });
                } else {
                  if (_isActive) {
                    emit(state.copyWith(
                      status: TaskStatus.success,
                      tasks: tasks,
                      filteredTasks: tasks,
                    ));
                  }
                }
              } catch (e) {
                if (_isActive) {
                  emit(state.copyWith(
                    status: TaskStatus.failure,
                    errorMessage: 'Error updating tasks: ${e.toString()}',
                  ));
                }
              }
            },
            onError: (error, stackTrace) {
              if (_isActive) {
                emit(state.copyWith(
                  status: TaskStatus.failure,
                  errorMessage: 'Task stream error: ${error.toString()}',
                ));
              }
            },
          );
          print('Task subscription re-established');
        });
      } catch (e) {
        print('Error during TaskBloc reactivation: $e');
        if (_isActive) {
          emit(state.copyWith(
            status: TaskStatus.failure,
            errorMessage: 'Failed to load tasks: ${e.toString()}',
          ));
        }
      }
    } else {
      // If already active, just force a refresh
      print('TaskBloc already active, forcing refresh');
      add(ForceRefreshTasks(userId: userId));
    }
  }

  String _getCurrentUserId() {
    if (state.tasks.isNotEmpty) {
      for (final task in state.tasks) {
        if (!task.sharedWith.contains(task.userId)) {
          return task.userId;
        }
      }

      return state.tasks.first.userId;
    }

    return '';
  }

  Future<void> shutdown() async {
    _isActive = false;

    _filterDebouncer?.cancel();

    emit(const TaskState());

    await _tasksSubscription.cancel();
  }

  Future<void> _onResetTaskBloc(
      ResetTaskBloc event, Emitter<TaskState> emit) async {
    await shutdown();
  }

  void resetAndClearSubscriptions() {
    _filterDebouncer?.cancel();

    _isActive = false;

    emit(const TaskState());
  }

  Future<void> createTaskWithCallback({
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required String userId,
    required List<Subtask> subtasks,
    required Function(String) onSuccess,
  }) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      if (userId.isEmpty) {
        throw Exception('Cannot create task: User ID is empty');
      }

      final String taskId = await _taskRepository.createTask(
        title: title,
        description: description,
        dueDate: dueDate,
        priority: priority,
        userId: userId,
        subtasks: subtasks,
      );

      try {
        final task = Task(
          id: taskId,
          title: title,
          description: description,
          dueDate: dueDate,
          priority: priority,
          isCompleted: false,
          userId: userId,
          subtasks: subtasks,
          createdAt: DateTime.now(),
          sharedWith: const [],
        );

        await NotificationHelper.scheduleTaskReminder(task);
      } catch (e) {
        print('Failed to schedule notification for task: ${e.toString()}');
      }

      if (!_isActive) return;

      emit(state.copyWith(
        status: TaskStatus.success,
        lastCreatedTaskId: taskId,
      ));

      onSuccess(taskId);
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to create task: ${e.toString()}',
      ));
    }
  }

  Future<void> _onResetTasks(ResetTasks event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      await _taskRepository.reset();

      emit(const TaskState());

      if (event.userId.isNotEmpty) {
        await _taskRepository.init(event.userId);
      }
    } catch (e, stackTrace) {
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to reset tasks: ${e.toString()}',
      ));
    }
  }

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      if (event.userId.isEmpty) {
        throw Exception('Cannot load tasks: User ID is empty');
      }

      await _taskRepository.init(event.userId);
      final tasks = await _taskRepository.getAllTasks(event.userId);

      for (final task in tasks) {
        if (!task.isCompleted) {
          try {
            await NotificationHelper.scheduleTaskReminder(task);
          } catch (e) {
            print(e);
          }
        }
      }

      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.success,
        tasks: tasks,
        filteredTasks: tasks,
      ));
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to load tasks: ${e.toString()}',
      ));
    }
  }

  Future<void> _onAddTask(AddTask event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(
      status: TaskStatus.loading,
      lastCreatedTaskId: null,
    ));

    try {
      if (event.userId.isEmpty) {
        throw Exception('Cannot create task: User ID is empty');
      }

      final String taskId = await _taskRepository.createTask(
        title: event.title,
        description: event.description,
        dueDate: event.dueDate,
        priority: event.priority,
        userId: event.userId,
        subtasks: event.subtasks,
      );

      try {
        final task = Task(
          id: taskId,
          title: event.title,
          description: event.description,
          dueDate: event.dueDate,
          priority: event.priority,
          isCompleted: false,
          userId: event.userId,
          subtasks: event.subtasks,
          createdAt: DateTime.now(),
          sharedWith: const [],
        );

        await NotificationHelper.scheduleTaskReminder(task);
      } catch (e) {
        print('Failed to schedule notification for task: ${e.toString()}');
      }

      if (!_isActive) return;

      emit(state.copyWith(
        status: TaskStatus.success,
        lastCreatedTaskId: taskId,
      ));
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to create task: ${e.toString()}',
        lastCreatedTaskId: null,
      ));
    }
  }

  Future<void> _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      final String currentUserId = _getCurrentUserId();

      try {
        await NotificationHelper.cancelTaskReminder(event.task.id);
      } catch (e) {
        print(e);
      }

      await _taskRepository.updateTask(
        event.task,
        currentUserId: currentUserId,
      );

      if (!event.task.isCompleted) {
        try {
          await NotificationHelper.scheduleTaskReminder(event.task);
        } catch (e) {
          print('Failed to schedule notification for task: ${e.toString()}');
        }
      }

      if (!_isActive) return;
      emit(state.copyWith(status: TaskStatus.success));
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to update task: ${e.toString()}',
      ));
    }
  }

  Future<void> _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      if (event.taskId.isEmpty || event.userId.isEmpty) {
        throw Exception('Cannot delete task: Invalid IDs');
      }

      try {
        await NotificationHelper.cancelTaskReminder(event.taskId);
      } catch (e) {
        print(e);
      }

      await _taskRepository.deleteTask(event.taskId, event.userId);

      if (!_isActive) return;
      emit(state.copyWith(status: TaskStatus.success));
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to delete task: ${e.toString()}',
      ));
    }
  }

  Future<void> _onToggleTaskCompletion(
      ToggleTaskCompletion event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      final String currentUserId = _getCurrentUserId();

      final currentTasks = List<Task>.from(state.tasks);
      final currentFilteredTasks = List<Task>.from(state.filteredTasks);

      for (int i = 0; i < currentTasks.length; i++) {
        if (currentTasks[i].id == event.taskId) {
          final updatedTask = currentTasks[i].copyWith(
            isCompleted: !currentTasks[i].isCompleted,
          );
          currentTasks[i] = updatedTask;
          break;
        }
      }

      for (int i = 0; i < currentFilteredTasks.length; i++) {
        if (currentFilteredTasks[i].id == event.taskId) {
          final updatedTask = currentFilteredTasks[i].copyWith(
            isCompleted: !currentFilteredTasks[i].isCompleted,
          );
          currentFilteredTasks[i] = updatedTask;
          break;
        }
      }

      emit(state.copyWith(
        status: TaskStatus.success,
        tasks: currentTasks,
        filteredTasks: currentFilteredTasks,
      ));

      await _taskRepository.toggleTaskCompletion(
        event.taskId,
        event.userId,
        currentUserId: currentUserId,
      );
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to toggle task completion: ${e.toString()}',
      ));
    }
  }

  Future<void> _onAddSubtask(AddSubtask event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      final String currentUserId = _getCurrentUserId();

      await _taskRepository.addSubtask(
        event.taskId,
        event.subtaskTitle,
        event.userId,
        currentUserId: currentUserId,
      );

      if (!_isActive) return;
      emit(state.copyWith(status: TaskStatus.success));
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to add subtask: ${e.toString()}',
      ));
    }
  }

  void _onForceRefreshTasks(
      ForceRefreshTasks event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));

    try {
      if (event.userId.isEmpty) {
        throw Exception('Cannot refresh tasks: User ID is empty');
      }

      await _taskRepository.clearLocalCache();

      await _taskRepository.init(event.userId);

      final tasks = await _taskRepository.getAllTasks(event.userId);

      if (!_isActive) return;

      emit(state.copyWith(
        status: TaskStatus.success,
        tasks: tasks,
        filteredTasks: tasks,
        activeFilter: state.activeFilter,
        priorityFilter: state.priorityFilter,
        searchQuery: state.searchQuery,
      ));
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to refresh tasks: ${e.toString()}',
      ));
    }
  }

  Future<void> _onUpdateSubtask(
      UpdateSubtask event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      final String currentUserId = _getCurrentUserId();

      await _taskRepository.updateSubtask(
        event.taskId,
        event.subtask,
        event.userId,
        currentUserId: currentUserId,
      );

      if (!_isActive) return;
      emit(state.copyWith(status: TaskStatus.success));
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to update subtask: ${e.toString()}',
      ));
    }
  }

  Future<void> _onToggleSubtaskCompletion(
      ToggleSubtaskCompletion event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      final String currentUserId = _getCurrentUserId();

      await _taskRepository.toggleSubtaskCompletion(
        event.taskId,
        event.subtaskId,
        event.userId,
        currentUserId: currentUserId,
      );

      if (!_isActive) return;
      emit(state.copyWith(status: TaskStatus.success));
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to toggle subtask completion: ${e.toString()}',
      ));
    }
  }

  Future<void> _onDeleteSubtask(
      DeleteSubtask event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    emit(state.copyWith(status: TaskStatus.loading));
    try {
      final String currentUserId = _getCurrentUserId();

      await _taskRepository.deleteSubtask(
        event.taskId,
        event.subtaskId,
        event.userId,
        currentUserId: currentUserId,
      );

      if (!_isActive) return;
      emit(state.copyWith(status: TaskStatus.success));
    } catch (e, stackTrace) {
      if (!_isActive) return;
      emit(state.copyWith(
        status: TaskStatus.failure,
        errorMessage: 'Failed to delete subtask: ${e.toString()}',
      ));
    }
  }

  Future<void> _onFilterTasks(
      FilterTasks event, Emitter<TaskState> emit) async {
    if (!_isActive) return;

    if (event.userId.isEmpty) {
      return;
    }

    if (_isFiltering) {
      return;
    }

    _isFiltering = true;

    try {
      emit(state.copyWith(status: TaskStatus.loading));

      List<Task> allTasks = state.tasks;

      if (allTasks.isEmpty) {
        allTasks = await _taskRepository.getAllTasks(event.userId);
      } else {}

      if (!_isActive) {
        _isFiltering = false;
        return;
      }

      List<Task> filteredTasks = [];

      switch (event.filter) {
        case TaskFilter.all:
          filteredTasks = allTasks;
          break;
        case TaskFilter.completed:
          filteredTasks = allTasks.where((task) => task.isCompleted).toList();
          break;
        case TaskFilter.incomplete:
          filteredTasks = allTasks.where((task) => !task.isCompleted).toList();
          break;
        case TaskFilter.today:
          filteredTasks = allTasks.where((task) => task.isDueToday()).toList();
          break;
        case TaskFilter.overdue:
          filteredTasks = allTasks
              .where((task) => task.isOverdue() && !task.isCompleted)
              .toList();
          break;
        case TaskFilter.byPriority:
          if (event.priorityFilter != null) {
            filteredTasks = allTasks
                .where((task) => task.priority == event.priorityFilter)
                .toList();
          } else {
            filteredTasks = allTasks;
          }
          break;
        case TaskFilter.search:
          if (event.searchQuery != null && event.searchQuery!.isNotEmpty) {
            final query = event.searchQuery!.toLowerCase();
            filteredTasks = allTasks.where((task) {
              return task.title.toLowerCase().contains(query) ||
                  task.description.toLowerCase().contains(query);
            }).toList();
          } else {
            filteredTasks = allTasks;
          }
          break;
      }

      if (!_isActive) {
        _isFiltering = false;
        return;
      }

      emit(state.copyWith(
        status: TaskStatus.success,
        tasks: allTasks,
        filteredTasks: filteredTasks,
        activeFilter: event.filter,
        priorityFilter: event.priorityFilter,
        searchQuery: event.searchQuery,
      ));
    } catch (e, stackTrace) {
      if (_isActive) {
        emit(state.copyWith(
          status: TaskStatus.failure,
          errorMessage: 'Failed to filter tasks: ${e.toString()}',
        ));
      }
    } finally {
      _isFiltering = false;
    }
  }

  @override
  Future<void> close() {
    _isActive = false;
    _filterDebouncer?.cancel();
    _tasksSubscription.cancel();
    _taskRepository.dispose();
    return super.close();
  }
}
