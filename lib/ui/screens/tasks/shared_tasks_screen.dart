import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/tasks/task_bloc.dart';
import '../../../blocs/tasks/task_event.dart';
import '../../../data/models/task.dart';
import '../../../data/services/tasks/task_sharing_service.dart';
import '../../theme/theme_constants.dart';
import '../../widgets/tasks/task_card.dart';

class SharedTasksScreen extends StatefulWidget {
  const SharedTasksScreen({Key? key}) : super(key: key);

  @override
  State<SharedTasksScreen> createState() => _SharedTasksScreenState();
}

class _SharedTasksScreenState extends State<SharedTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Task> _sharedWithMe = [];
  List<Task> _sharedByMe = [];
  bool _isLoading = true;
  String? _errorMessage;

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSharedTasks();
  }

  Future<void> _loadSharedTasks() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final taskSharingService = context.read<TaskSharingService>();

      for (var subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();

      if (!mounted) return;
      setState(() {
        _sharedWithMe = [];
        _sharedByMe = [];
      });

      final sharedWithMeSubscription =
          taskSharingService.getSharedTasksForCurrentUser().listen(
        (tasks) {
          if (!mounted) return;
          setState(() {
            _sharedWithMe = tasks;
            _isLoading = false;
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Error loading shared tasks: $e';
            _isLoading = false;
          });
        },
        cancelOnError: true,
      );

      final sharedByMeSubscription =
          taskSharingService.getTasksSharedByCurrentUser().listen(
        (tasks) {
          if (!mounted) return;
          setState(() {
            _sharedByMe = tasks;
            _isLoading = false;
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _errorMessage = 'Error loading tasks you shared: $e';
            _isLoading = false;
          });
        },
        cancelOnError: true,
      );

      _subscriptions.addAll([
        sharedWithMeSubscription,
        sharedByMeSubscription,
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    _tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Tasks'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Theme.of(context).colorScheme.secondary,
          tabs: const [
            Tab(
              text: 'Shared with me',
            ),
            Tab(text: 'Shared by me'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 60, color: Colors.red),
                        const SizedBox(height: AppDimensions.paddingM),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppDimensions.paddingL),
                        ElevatedButton(
                          onPressed: _loadSharedTasks,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(_sharedWithMe, isSharedWithMe: true),
                    _buildTaskList(_sharedByMe, isSharedWithMe: false),
                  ],
                ),
    );
  }

  Widget _buildTaskList(List<Task> tasks, {required bool isSharedWithMe}) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSharedWithMe ? Icons.folder_shared : Icons.share,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Text(
              isSharedWithMe
                  ? 'No tasks shared with you yet'
                  : 'You haven\'t shared any tasks yet',
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Text(
              isSharedWithMe
                  ? 'Tasks shared with you will appear here'
                  : 'Share your tasks with others to collaborate',
              style: AppTextStyles.body2,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSharedTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
            child: TaskCard(
              task: task,
              onTap: () => Navigator.pushNamed(
                context,
                '/task/detail',
                arguments: task.id,
              ),
              onToggleCompletion: () {
                context.read<TaskBloc>().add(
                      ToggleTaskCompletion(
                        taskId: task.id,
                        userId: task.userId,
                      ),
                    );
              },
              onDelete: isSharedWithMe
                  ? null
                  : () => _showDeleteConfirmation(context, task),
              showSharedBadge: true,
              ownerName: isSharedWithMe ? task.ownerName : null,
            ),
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Task task) {
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
              context.read<TaskBloc>().add(
                    DeleteTask(
                      taskId: task.id,
                      userId: task.userId,
                    ),
                  );
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
