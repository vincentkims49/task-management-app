import 'package:flutter/material.dart';

import '../../../data/models/subtask.dart';
import '../../theme/theme_constants.dart';

class SubtaskList extends StatelessWidget {
  final List<Subtask> subtasks;
  final Function(int) onDelete;
  final Function(int) onToggle;

  const SubtaskList({
    Key? key,
    required this.subtasks,
    required this.onDelete,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (subtasks.isEmpty) {
      return const Center(
        child: Text(
          'No subtasks added yet',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: AppColors.secondaryTextColor,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: subtasks.length,
      itemBuilder: (context, index) {
        final subtask = subtasks[index];
        return Dismissible(
          key: Key(subtask.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
            ),
          ),
          onDismissed: (_) => onDelete(index),
          child: Card(
            margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
            child: ListTile(
              leading: Checkbox(
                value: subtask.isCompleted,
                onChanged: (_) => onToggle(index),
                activeColor: AppColors.completedColor,
              ),
              title: Text(
                subtask.title,
                style: TextStyle(
                  decoration:
                      subtask.isCompleted ? TextDecoration.lineThrough : null,
                  color:
                      subtask.isCompleted ? AppColors.secondaryTextColor : null,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => onDelete(index),
                color: Colors.red,
              ),
            ),
          ),
        );
      },
    );
  }
}
