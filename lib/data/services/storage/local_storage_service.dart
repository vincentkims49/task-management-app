import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/task.dart';
import '../../models/subtask.dart';

class LocalStorageService {
  static const String _taskBoxName = 'tasks';
  final Logger _logger;

  LocalStorageService({Logger? logger}) : _logger = logger ?? Logger();

  Future<void> init() async {
    try {
      final appDocumentDir = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(appDocumentDir.path);

      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(TaskPriorityAdapter());
      }

      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(SubtaskAdapter());
      }

      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(TaskAdapter());
      }

      await Hive.openBox<Task>(_taskBoxName);
    } catch (e) {
      throw Exception(
          'Failed to initialize local storage. Please restart the app.');
    }
  }

  Future<void> saveTask(Task task) async {
    try {
      final box = Hive.box<Task>(_taskBoxName);
      await box.put(task.id, task);
    } catch (e) {
      throw Exception('Failed to save task. Please try again.');
    }
  }

  Future<void> saveAllTasks(List<Task> tasks) async {
    try {
      final box = Hive.box<Task>(_taskBoxName);
      final Map<String, Task> tasksMap = {
        for (var task in tasks) task.id: task
      };
      await box.putAll(tasksMap);
    } catch (e) {
      throw Exception('Failed to save tasks. Please try again.');
    }
  }

  Future<Task?> getTask(String taskId) async {
    try {
      final box = Hive.box<Task>(_taskBoxName);
      return box.get(taskId);
    } catch (e) {
      throw Exception('Failed to retrieve task. Please try again.');
    }
  }

  Future<List<Task>> getAllTasks() async {
    try {
      final box = Hive.box<Task>(_taskBoxName);
      return box.values.toList();
    } catch (e) {
      throw Exception('Failed to retrieve tasks. Please try again.');
    }
  }

  Future<List<Task>> getTasksByUserId(String userId) async {
    try {
      final box = Hive.box<Task>(_taskBoxName);
      return box.values.where((task) => task.userId == userId).toList();
    } catch (e) {
      throw Exception('Failed to retrieve tasks. Please try again.');
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final box = Hive.box<Task>(_taskBoxName);
      await box.delete(taskId);
    } catch (e) {
      throw Exception('Failed to delete task. Please try again.');
    }
  }

  Future<void> clearAllTasks() async {
    try {
      final box = Hive.box<Task>(_taskBoxName);
      await box.clear();
    } catch (e) {
      throw Exception('Failed to clear tasks. Please try again.');
    }
  }

  Future<void> clearUserTasks(String userId) async {
    try {
      final box = Hive.box<Task>(_taskBoxName);
      final userTaskKeys = box.values
          .where((task) => task.userId == userId)
          .map((task) => task.id)
          .toList();

      for (final key in userTaskKeys) {
        await box.delete(key);
      }
    } catch (e) {
      throw Exception('Failed to clear tasks. Please try again.');
    }
  }
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      dueDate: fields[3] as DateTime,
      priority: fields[4] as TaskPriority,
      isCompleted: fields[5] as bool,
      subtasks: (fields[6] as List).cast<Subtask>(),
      createdAt: fields[7] as DateTime,
      userId: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeByte(9);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.description);
    writer.writeByte(3);
    writer.write(obj.dueDate);
    writer.writeByte(4);
    writer.write(obj.priority);
    writer.writeByte(5);
    writer.write(obj.isCompleted);
    writer.writeByte(6);
    writer.write(obj.subtasks);
    writer.writeByte(7);
    writer.write(obj.createdAt);
    writer.writeByte(8);
    writer.write(obj.userId);
  }
}

class SubtaskAdapter extends TypeAdapter<Subtask> {
  @override
  final int typeId = 1;

  @override
  Subtask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return Subtask(
      id: fields[0] as String,
      title: fields[1] as String,
      isCompleted: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Subtask obj) {
    writer.writeByte(3);
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.title);
    writer.writeByte(2);
    writer.write(obj.isCompleted);
  }
}

class TaskPriorityAdapter extends TypeAdapter<TaskPriority> {
  @override
  final int typeId = 2;

  @override
  TaskPriority read(BinaryReader reader) {
    return TaskPriority.values[reader.readInt()];
  }

  @override
  void write(BinaryWriter writer, TaskPriority obj) {
    writer.writeInt(obj.index);
  }
}
