import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'subtask.g.dart';

@HiveType(typeId: 2)
class Subtask extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final bool isCompleted;

  const Subtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  factory Subtask.create({
    required String title,
  }) {
    return Subtask(
      id: const Uuid().v4(),
      title: title,
      isCompleted: false,
    );
  }

  Subtask copyWith({
    String? title,
    bool? isCompleted,
  }) {
    return Subtask(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] ?? const Uuid().v4(),
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
    };
  }

  @override
  List<Object?> get props => [id, title, isCompleted];
}
