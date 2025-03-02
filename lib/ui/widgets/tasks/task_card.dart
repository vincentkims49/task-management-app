import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../data/models/task.dart';
import '../../theme/theme_constants.dart';
import 'priority_badge.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggleCompletion;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool showSharedBadge;
  final String? ownerName;

  const TaskCard({
    Key? key,
    required this.task,
    required this.onTap,
    required this.onToggleCompletion,
    required this.onDelete,
    this.onEdit,
    this.showSharedBadge = false,
    this.ownerName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = task.isOverdue() && !task.isCompleted;

    return Slidable(
      key: ValueKey(task.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onToggleCompletion(),
            backgroundColor:
                task.isCompleted ? Colors.orange : AppColors.completedColor,
            foregroundColor: Colors.white,
            icon: task.isCompleted ? Icons.refresh : Icons.check_circle,
            label: task.isCompleted ? 'Reopen' : 'Complete',
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppDimensions.borderRadiusL),
            ),
          ),
          if (onEdit != null)
            SlidableAction(
              onPressed: (_) => onEdit!(),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: 'Edit',
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete!(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(AppDimensions.borderRadiusL),
              ),
            ),
        ],
      ),
      child: Card(
        elevation: AppDimensions.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          side: task.isCompleted
              ? const BorderSide(
                  color: AppColors.completedColor,
                  width: 2,
                )
              : isOverdue
                  ? const BorderSide(
                      color: AppColors.overdueColor,
                      width: 2,
                    )
                  : BorderSide.none,
        ),
        color: isDarkMode
            ? task.isCompleted
                ? Colors.green[900]
                : isOverdue
                    ? Colors.red[900]
                    : null
            : task.isCompleted
                ? Colors.green[50]
                : isOverdue
                    ? Colors.red[50]
                    : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: AppTextStyles.heading2.copyWith(
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isDarkMode
                                        ? Colors.white
                                        : task.isCompleted
                                            ? Colors.green[800]
                                            : isOverdue
                                                ? Colors.red[800]
                                                : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (showSharedBadge)
                                Container(
                                  margin: const EdgeInsets.only(
                                      left: AppDimensions.paddingXS),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppDimensions.paddingXS,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accentColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(
                                        AppDimensions.borderRadiusS),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 12,
                                        color: AppColors.accentColor,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        'Shared',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.accentColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (ownerName != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'From: $ownerName',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          if (task.description.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.paddingXS),
                            Text(
                              task.description,
                              style: AppTextStyles.body2.copyWith(
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Checkbox(
                      value: task.isCompleted,
                      onChanged: (_) => onToggleCompletion(),
                      activeColor: AppColors.completedColor,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingS),
                if (task.subtasks.isNotEmpty) ...[
                  LinearProgressIndicator(
                    value: task.completionPercentage,
                    backgroundColor:
                        isDarkMode ? Colors.grey[800] : Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      task.completionPercentage == 1.0
                          ? AppColors.completedColor
                          : AppColors.primaryColor,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                  Text(
                    '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length} subtasks',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppDimensions.paddingS),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: AppDimensions.iconSizeS,
                          color: AppColors.secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d').format(task.dueDate),
                          style: AppTextStyles.caption.copyWith(
                            color: isOverdue
                                ? AppColors.overdueColor
                                : AppColors.secondaryTextColor,
                            fontWeight:
                                isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.paddingXS),
                        const Icon(
                          Icons.access_time,
                          size: AppDimensions.iconSizeS,
                          color: AppColors.secondaryTextColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('h:mm a').format(task.dueDate),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    PriorityBadge(priority: task.priority),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
