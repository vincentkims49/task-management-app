import 'package:equatable/equatable.dart';

import '../../data/models/task.dart';
import '../../data/models/subtask.dart';
import '../../data/models/task_filter.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {
  final String userId;

  const LoadTasks({required this.userId});

  @override
  List<Object> get props => [userId];
}

class AddTask extends TaskEvent {
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskPriority priority;
  final String userId;
  final List<Subtask> subtasks;

  const AddTask({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.userId,
    this.subtasks = const [],
  });

  @override
  List<Object> get props => [
        title,
        description,
        dueDate,
        priority,
        userId,
        subtasks,
      ];
}

class UpdateTask extends TaskEvent {
  final Task task;

  const UpdateTask({required this.task});

  @override
  List<Object> get props => [task];
}

class DeleteTask extends TaskEvent {
  final String taskId;
  final String userId;

  const DeleteTask({
    required this.taskId,
    required this.userId,
  });

  @override
  List<Object> get props => [taskId, userId];
}

class ToggleTaskCompletion extends TaskEvent {
  final String taskId;
  final String userId;

  const ToggleTaskCompletion({
    required this.taskId,
    required this.userId,
  });

  @override
  List<Object> get props => [taskId, userId];
}

class AddSubtask extends TaskEvent {
  final String taskId;
  final String subtaskTitle;
  final String userId;

  const AddSubtask({
    required this.taskId,
    required this.subtaskTitle,
    required this.userId,
  });

  @override
  List<Object> get props => [taskId, subtaskTitle, userId];
}

class UpdateSubtask extends TaskEvent {
  final String taskId;
  final Subtask subtask;
  final String userId;

  const UpdateSubtask({
    required this.taskId,
    required this.subtask,
    required this.userId,
  });

  @override
  List<Object> get props => [taskId, subtask, userId];
}

class ToggleSubtaskCompletion extends TaskEvent {
  final String taskId;
  final String subtaskId;
  final String userId;

  const ToggleSubtaskCompletion({
    required this.taskId,
    required this.subtaskId,
    required this.userId,
  });

  @override
  List<Object> get props => [taskId, subtaskId, userId];
}

class DeleteSubtask extends TaskEvent {
  final String taskId;
  final String subtaskId;
  final String userId;

  const DeleteSubtask({
    required this.taskId,
    required this.subtaskId,
    required this.userId,
  });

  @override
  List<Object> get props => [taskId, subtaskId, userId];
}

class ResetTasks extends TaskEvent {
  final String userId;

  const ResetTasks({required this.userId});

  @override
  List<Object> get props => [userId];
}

class ResetTaskBloc extends TaskEvent {
  const ResetTaskBloc();

  @override
  List<Object> get props => [];
}

class ForceRefreshTasks extends TaskEvent {
  final String userId;

  const ForceRefreshTasks({required this.userId});
}

class FilterTasks extends TaskEvent {
  final String userId;
  final TaskFilter filter;
  final TaskPriority? priorityFilter;
  final String? searchQuery;

  const FilterTasks({
    required this.userId,
    required this.filter,
    this.priorityFilter,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [userId, filter, priorityFilter, searchQuery];
}
