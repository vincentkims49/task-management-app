import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'subtask.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
enum TaskPriority {
  @HiveField(0)
  low,

  @HiveField(1)
  medium,

  @HiveField(2)
  high
}

@HiveType(typeId: 1)
class Task extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final DateTime dueDate;

  @HiveField(4)
  final TaskPriority priority;

  @HiveField(5)
  final bool isCompleted;

  @HiveField(6)
  final List<Subtask> subtasks;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  final String userId;

  @HiveField(9)
  final List<String> sharedWith;

  @HiveField(10)
  final Map<String, String> sharedWithDetails;

  @HiveField(11)
  final String ownerName;

  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    this.isCompleted = false,
    this.subtasks = const [],
    required this.createdAt,
    required this.userId,
    this.sharedWith = const [],
    this.sharedWithDetails = const {},
    this.ownerName = '',
  });

  factory Task.create({
    required String title,
    required String description,
    required DateTime dueDate,
    required TaskPriority priority,
    required String userId,
    required String ownerName,
    List<Subtask> subtasks = const [],
  }) {
    return Task(
      id: const Uuid().v4(),
      title: title,
      description: description,
      dueDate: dueDate,
      priority: priority,
      isCompleted: false,
      subtasks: subtasks,
      createdAt: DateTime.now(),
      userId: userId,
      ownerName: ownerName,
    );
  }

  Task copyWith({
    String? title,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    bool? isCompleted,
    List<Subtask>? subtasks,
    String? userId,
    List<String>? sharedWith,
    Map<String, String>? sharedWithDetails,
    String? ownerName,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt,
      userId: userId ?? this.userId,
      sharedWith: sharedWith ?? this.sharedWith,
      sharedWithDetails: sharedWithDetails ?? this.sharedWithDetails,
      ownerName: ownerName ?? this.ownerName,
    );
  }

  bool isDueToday() {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day;
  }

  bool isOverdue() {
    final now = DateTime.now();
    return dueDate.isBefore(DateTime(now.year, now.month, now.day));
  }

  double get completionPercentage {
    if (subtasks.isEmpty) return isCompleted ? 1.0 : 0.0;
    return subtasks.where((subtask) => subtask.isCompleted).length /
        subtasks.length;
  }

  factory Task.fromFirestore(Map<String, dynamic> data, String id) {
    return Task(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      priority: TaskPriority.values[data['priority'] ?? 0],
      isCompleted: data['isCompleted'] ?? false,
      subtasks: ((data['subtasks'] ?? []) as List<dynamic>)
          .map((subtask) => Subtask.fromMap(subtask as Map<String, dynamic>))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
      sharedWith: List<String>.from(data['sharedWith'] ?? []),
      sharedWithDetails:
          Map<String, String>.from(data['sharedWithDetails'] ?? {}),
      ownerName: data['ownerName'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority.index,
      'isCompleted': isCompleted,
      'subtasks': subtasks.map((subtask) => subtask.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'userId': userId,
      'sharedWith': sharedWith,
      'sharedWithDetails': sharedWithDetails,
      'ownerName': ownerName,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        dueDate,
        priority,
        isCompleted,
        subtasks,
        createdAt,
        userId,
        sharedWith,
        sharedWithDetails,
        ownerName,
      ];
}
