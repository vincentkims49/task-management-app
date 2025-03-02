import 'package:equatable/equatable.dart';

import '../../data/models/task.dart';
import '../../data/models/task_filter.dart';

enum TaskStatus { initial, loading, success, failure }

class TaskState extends Equatable {
  final TaskStatus status;
  final List<Task> tasks;
  final List<Task> filteredTasks;
  final TaskFilter activeFilter;
  final TaskPriority? priorityFilter;
  final String? searchQuery;
  final String? errorMessage;
  final String? lastCreatedTaskId;

  const TaskState({
    this.status = TaskStatus.initial,
    this.tasks = const [],
    this.filteredTasks = const [],
    this.activeFilter = TaskFilter.all,
    this.priorityFilter,
    this.searchQuery,
    this.errorMessage,
    this.lastCreatedTaskId,
  });

  TaskState copyWith({
    TaskStatus? status,
    List<Task>? tasks,
    List<Task>? filteredTasks,
    TaskFilter? activeFilter,
    TaskPriority? priorityFilter,
    String? searchQuery,
    String? errorMessage,
    String? lastCreatedTaskId,
  }) {
    return TaskState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      filteredTasks: filteredTasks ?? this.filteredTasks,
      activeFilter: activeFilter ?? this.activeFilter,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
      lastCreatedTaskId: lastCreatedTaskId ?? this.lastCreatedTaskId,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tasks,
        filteredTasks,
        activeFilter,
        priorityFilter,
        searchQuery,
        errorMessage,
        lastCreatedTaskId,
      ];
}
