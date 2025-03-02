import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/tasks/task_bloc.dart';
import '../../../blocs/tasks/task_event.dart';
import '../../../data/models/subtask.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/services/tasks/task_sharing_service.dart';
import '../../theme/theme_constants.dart';
import '../../widgets/tasks/priority_badge.dart';
import '../../widgets/tasks/share_task_dialog.dart';
import '../../widgets/tasks/subtask_tile.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({
    Key? key,
    required this.taskId,
  }) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  Task? _task;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimations.mediumDuration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _loadTask();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTask() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final taskRepository = context.read<TaskRepository>();
      final task = await taskRepository.getTask(widget.taskId);

      setState(() {
        _task = task;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load task: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          if (_task != null) ...[
            if (_task!.userId == context.read<AuthBloc>().state.userId)
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _showShareTaskDialog,
              ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.pushNamed(
                context,
                '/task/edit',
                arguments: _task,
              ).then((_) => _loadTask()),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _task == null
              ? const Center(child: Text('Task not found'))
              : _buildTaskDetails(),
    );
  }

  Widget _buildTaskDetails() {
    final task = _task!;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTaskHeader(task),
            const SizedBox(height: AppDimensions.paddingM),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    Text(
                      task.description.isNotEmpty
                          ? task.description
                          : 'No description provided',
                      style: task.description.isNotEmpty
                          ? AppTextStyles.body1
                          : AppTextStyles.body2.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Details',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppDimensions.paddingS),
                    ListTile(
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('Due Date'),
                      subtitle: Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(task.dueDate),
                      ),
                      dense: true,
                    ),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Due Time'),
                      subtitle: Text(
                        DateFormat('h:mm a').format(task.dueDate),
                      ),
                      dense: true,
                    ),
                    ListTile(
                      leading: const Icon(Icons.flag),
                      title: const Text('Priority'),
                      subtitle: Row(
                        children: [
                          PriorityBadge(priority: task.priority),
                        ],
                      ),
                      dense: true,
                    ),
                    ListTile(
                      leading: const Icon(Icons.check_circle),
                      title: const Text('Status'),
                      subtitle: Text(
                        task.isCompleted ? 'Completed' : 'In Progress',
                      ),
                      trailing: Switch(
                        value: task.isCompleted,
                        onChanged: (value) => _toggleTaskCompletion(task),
                        activeColor: AppColors.completedColor,
                      ),
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
            if (task.subtasks.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.paddingM),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Subtasks',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length}',
                            style: AppTextStyles.body2,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.paddingS),
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
                      const SizedBox(height: AppDimensions.paddingM),
                      ...task.subtasks.asMap().entries.map((entry) {
                        final index = entry.key;
                        final subtask = entry.value;
                        return SubtaskTile(
                          subtask: subtask,
                          onToggle: () => _toggleSubtaskCompletion(task, index),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.paddingL),
            if (_task != null &&
                (_task!.sharedWith.isNotEmpty ||
                    _task!.userId !=
                        context.read<AuthBloc>().state.userId)) ...[
              const SizedBox(height: AppDimensions.paddingM),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sharing',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppDimensions.paddingS),
                      if (_task!.userId !=
                          context.read<AuthBloc>().state.userId) ...[
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.primaryColor,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(_task!.ownerName.isNotEmpty
                              ? _task!.ownerName
                              : 'Task Owner'),
                          subtitle: const Text('Owner'),
                          dense: true,
                        ),
                        const Divider(),
                      ],
                      if (_task!.userId ==
                              context.read<AuthBloc>().state.userId &&
                          _task!.sharedWith.isNotEmpty) ...[
                        ...List.generate(_task!.sharedWith.length, (index) {
                          final userId = _task!.sharedWith[index];
                          final userName =
                              _task!.sharedWithDetails[userId] ?? 'User';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[300],
                              child: Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(color: Colors.grey[800]),
                              ),
                            ),
                            title: Text(userName),
                            subtitle: const Text('Collaborator'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.red),
                              onPressed: () => _removeSharing(userId),
                            ),
                            dense: true,
                          );
                        }),
                      ],
                      if (_task!.userId ==
                              context.read<AuthBloc>().state.userId &&
                          _task!.sharedWith.isEmpty) ...[
                        const ListTile(
                          leading: Icon(Icons.people_outline),
                          title: Text('This task is not shared with anyone'),
                          subtitle: Text('Use the share button to collaborate'),
                          dense: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            ElevatedButton(
              onPressed: () => _showDeleteConfirmation(task),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.paddingM,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: AppDimensions.paddingS),
                  Text('DELETE TASK'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskHeader(Task task) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = task.isOverdue() && !task.isCompleted;

    return Card(
      color: isDarkMode
          ? task.isCompleted
              ? Colors.green[800]
              : isOverdue
                  ? Colors.red[900]
                  : null
          : task.isCompleted
              ? Colors.green[50]
              : isOverdue
                  ? Colors.red[50]
                  : null,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: AppTextStyles.heading1.copyWith(
                      color: isDarkMode
                          ? Colors.white
                          : task.isCompleted
                              ? Colors.green[800]
                              : isOverdue
                                  ? Colors.red[800]
                                  : null,
                    ),
                  ),
                ),
                Checkbox(
                  value: task.isCompleted,
                  onChanged: (_) => _toggleTaskCompletion(task),
                  activeColor: AppColors.completedColor,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingXS),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: AppDimensions.iconSizeS,
                  color: AppColors.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(task.dueDate),
                  style: AppTextStyles.body2,
                ),
                const SizedBox(width: AppDimensions.paddingS),
                const Icon(
                  Icons.access_time,
                  size: AppDimensions.iconSizeS,
                  color: AppColors.secondaryTextColor,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('h:mm a').format(task.dueDate),
                  style: AppTextStyles.body2,
                ),
              ],
            ),
            if (isOverdue) ...[
              const SizedBox(height: AppDimensions.paddingXS),
              Text(
                'Overdue by ${DateTime.now().difference(task.dueDate).inDays} days',
                style: AppTextStyles.body2.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showShareTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => ShareTaskDialog(task: _task!),
    ).then((value) {
      if (value == true) {
        _loadTask();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task shared successfully!')),
        );
      }
    });
  }

  void _removeSharing(String userId) {
    if (_task == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Sharing'),
        content: const Text(
            'Are you sure you want to remove this user from the shared task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final taskSharingService = context.read<TaskSharingService>();
                await taskSharingService.removeUserFromSharedTask(
                    _task!.id, userId);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('User removed from shared task')),
                );

                _loadTask();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
  }

  void _toggleTaskCompletion(Task task) {
    final userId = context.read<AuthBloc>().state.userId;
    if (userId != null) {
      context.read<TaskBloc>().add(
            ToggleTaskCompletion(
              taskId: task.id,
              userId: userId,
            ),
          );

      setState(() {
        _task = task.copyWith(isCompleted: !task.isCompleted);
      });
    }
  }

  void _toggleSubtaskCompletion(Task task, int subtaskIndex) {
    final userId = context.read<AuthBloc>().state.userId;
    if (userId != null) {
      final subtask = task.subtasks[subtaskIndex];
      context.read<TaskBloc>().add(
            ToggleSubtaskCompletion(
              taskId: task.id,
              subtaskId: subtask.id,
              userId: userId,
            ),
          );

      setState(() {
        final updatedSubtasks = List<Subtask>.from(task.subtasks);
        updatedSubtasks[subtaskIndex] = subtask.copyWith(
          isCompleted: !subtask.isCompleted,
        );
        _task = task.copyWith(subtasks: updatedSubtasks);
      });
    }
  }

  void _showDeleteConfirmation(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final userId = context.read<AuthBloc>().state.userId;
              if (userId != null) {
                context.read<TaskBloc>().add(
                      DeleteTask(
                        taskId: task.id,
                        userId: userId,
                      ),
                    );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
