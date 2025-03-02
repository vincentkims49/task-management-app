import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../blocs/auth/auth_bloc.dart';

import '../../../../data/models/task.dart';
import '../../../../data/models/task_filter.dart';
import '../../../blocs/tasks/task_bloc.dart';
import '../../../blocs/tasks/task_event.dart';
import '../../../blocs/tasks/task_state.dart';
import '../../theme/theme_constants.dart';

class TaskFilterBottomSheet extends StatelessWidget {
  const TaskFilterBottomSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingL,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadiusL),
            ),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Tasks',
                    style: AppTextStyles.heading1,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),
              BlocBuilder<TaskBloc, TaskState>(
                builder: (context, state) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppDimensions.paddingS),
                      _buildFilterOption(
                        context: context,
                        title: 'All Tasks',
                        subtitle: 'Show all tasks regardless of status',
                        icon: Icons.list,
                        isSelected: state.activeFilter == TaskFilter.all,
                        onTap: () => _applyFilter(
                          context,
                          TaskFilter.all,
                        ),
                      ),
                      _buildFilterOption(
                        context: context,
                        title: 'Completed Tasks',
                        subtitle: 'Show only completed tasks',
                        icon: Icons.check_circle,
                        isSelected: state.activeFilter == TaskFilter.completed,
                        onTap: () => _applyFilter(
                          context,
                          TaskFilter.completed,
                        ),
                      ),
                      _buildFilterOption(
                        context: context,
                        title: 'Incomplete Tasks',
                        subtitle: 'Show only tasks that are not completed',
                        icon: Icons.circle_outlined,
                        isSelected: state.activeFilter == TaskFilter.incomplete,
                        onTap: () => _applyFilter(
                          context,
                          TaskFilter.incomplete,
                        ),
                      ),
                      const Divider(),
                      Text(
                        'Due Date',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppDimensions.paddingS),
                      _buildFilterOption(
                        context: context,
                        title: 'Due Today',
                        subtitle: 'Show tasks due today',
                        icon: Icons.today,
                        isSelected: state.activeFilter == TaskFilter.today,
                        onTap: () => _applyFilter(
                          context,
                          TaskFilter.today,
                        ),
                      ),
                      _buildFilterOption(
                        context: context,
                        title: 'Overdue',
                        subtitle: 'Show tasks that are past their due date',
                        icon: Icons.warning,
                        isSelected: state.activeFilter == TaskFilter.overdue,
                        onTap: () => _applyFilter(
                          context,
                          TaskFilter.overdue,
                        ),
                      ),
                      const Divider(),
                      Text(
                        'Priority',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppDimensions.paddingS),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPriorityFilterOption(
                              context: context,
                              priority: TaskPriority.low,
                              isSelected:
                                  state.activeFilter == TaskFilter.byPriority &&
                                      state.priorityFilter == TaskPriority.low,
                              onTap: () => _applyFilter(
                                context,
                                TaskFilter.byPriority,
                                priorityFilter: TaskPriority.low,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildPriorityFilterOption(
                              context: context,
                              priority: TaskPriority.medium,
                              isSelected: state.activeFilter ==
                                      TaskFilter.byPriority &&
                                  state.priorityFilter == TaskPriority.medium,
                              onTap: () => _applyFilter(
                                context,
                                TaskFilter.byPriority,
                                priorityFilter: TaskPriority.medium,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _buildPriorityFilterOption(
                              context: context,
                              priority: TaskPriority.high,
                              isSelected:
                                  state.activeFilter == TaskFilter.byPriority &&
                                      state.priorityFilter == TaskPriority.high,
                              onTap: () => _applyFilter(
                                context,
                                TaskFilter.byPriority,
                                priorityFilter: TaskPriority.high,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      color: isSelected
          ? Theme.of(context).brightness == Brightness.dark
              ? AppColors.primaryColor.withOpacity(0.3)
              : AppColors.primaryColor.withOpacity(0.1)
          : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primaryColor : null,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primaryColor : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle,
                color: AppColors.primaryColor,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildPriorityFilterOption({
    required BuildContext context,
    required TaskPriority priority,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    Color color;
    String label;

    switch (priority) {
      case TaskPriority.low:
        color = AppColors.lowPriorityColor;
        label = 'Low';
        break;
      case TaskPriority.medium:
        color = AppColors.mediumPriorityColor;
        label = 'Medium';
        break;
      case TaskPriority.high:
        color = AppColors.highPriorityColor;
        label = 'High';
        break;
    }

    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingXS),
      color: isSelected ? color.withOpacity(0.2) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingS),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.flag,
                color: isSelected ? color : Colors.grey,
                size: 28,
              ),
              const SizedBox(height: AppDimensions.paddingXS),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyFilter(
    BuildContext context,
    TaskFilter filter, {
    TaskPriority? priorityFilter,
  }) {
    final userId = context.read<AuthBloc>().state.userId;
    if (userId != null) {
      context.read<TaskBloc>().add(
            FilterTasks(
              userId: userId,
              filter: filter,
              priorityFilter: priorityFilter,
            ),
          );
      Navigator.pop(context);
    }
  }
}
