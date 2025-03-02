import 'package:flutter/material.dart';

import '../../../data/models/subtask.dart';
import '../../theme/theme_constants.dart';

class SubtaskTile extends StatelessWidget {
  final Subtask subtask;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const SubtaskTile({
    Key? key,
    required this.subtask,
    required this.onToggle,
    this.onDelete,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      child: ListTile(
        leading: Checkbox(
          value: subtask.isCompleted,
          onChanged: (_) => onToggle(),
          activeColor: AppColors.completedColor,
        ),
        title: Text(
          subtask.title,
          style: TextStyle(
            decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
            color: subtask.isCompleted ? AppColors.secondaryTextColor : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
                color: Colors.blue,
                iconSize: AppDimensions.iconSizeM,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: onDelete,
                color: Colors.red,
                iconSize: AppDimensions.iconSizeM,
              ),
          ],
        ),
      ),
    );
  }
}
