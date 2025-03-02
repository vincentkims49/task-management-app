import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';

import '../../../blocs/auth/auth_bloc.dart';

import '../../../blocs/tasks/task_bloc.dart';
import '../../../blocs/tasks/task_event.dart';
import '../../../blocs/tasks/task_state.dart';
import '../../../blocs/theme/theme_bloc.dart';
import '../../../blocs/theme/theme_event.dart';
import '../../../blocs/theme/theme_state.dart';
import '../../../data/models/task.dart';
import '../../theme/theme_constants.dart';
import '../../widgets/tasks/task_card.dart';
import '../../widgets/tasks/task_filter_bottom_sheet.dart';
import '../../widgets/tasks/task_search_delegate.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({Key? key}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen>
    with TickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  @override
  void initState() {
    super.initState();

    _fabAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimations.mediumDuration,
    );

    _fabScaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: AppAnimations.bounceCurve,
      ),
    );

    _loadTasks();

    _fabAnimationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTasks();
  }

  void _loadTasks() {
    try {
      final userId = context.read<AuthBloc>().state.userId;
      if (userId != null && userId.isNotEmpty) {
        print('Loading tasks for user: $userId');

        context.read<TaskBloc>().reactivate(userId).then((_) {
          print('TaskBloc reactivation completed');

          context.read<TaskBloc>().add(ForceRefreshTasks(userId: userId));
        }).catchError((error) {
          print('Error reactivating TaskBloc: $error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading tasks: $error'),
              backgroundColor: Colors.red,
            ),
          );
        });
      } else {
        print('No user ID available for loading tasks');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated. Cannot load tasks.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Exception in _loadTasks: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading tasks: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterBottomSheet(context),
          ),
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                onPressed: () =>
                    context.read<ThemeBloc>().add(const ThemeToggled()),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<TaskBloc, TaskState>(
        listenWhen: (previous, current) =>
            previous.status != current.status &&
            current.status == TaskStatus.failure,
        listener: (context, state) {
          if (state.status == TaskStatus.failure &&
              state.errorMessage!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.errorMessage}'),
                backgroundColor: Colors.red,
                action: SnackBarAction(
                  label: 'RETRY',
                  textColor: Colors.white,
                  onPressed: _loadTasks,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == TaskStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.status == TaskStatus.loading &&
              state.filteredTasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.status == TaskStatus.failure) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load tasks',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.errorMessage != null && state.errorMessage!.isNotEmpty
                        ? state.errorMessage!
                        : 'An unexpected error occurred',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadTasks,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (state.filteredTasks.isEmpty) {
            return _buildEmptyState();
          } else {
            return _buildTaskList(state.filteredTasks);
          }
        },
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton.extended(
          heroTag: 'task_list_add_button',
          onPressed: () => Navigator.pushNamed(context, '/task/create'),
          icon: const Icon(Icons.add),
          label: const Text('New Task'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    Widget animationWidget;
    try {
      animationWidget = Lottie.asset(
        'lib/assets/animations/empty_tasks.json',
        width: 200,
        height: 200,
        repeat: true,
      );
    } catch (e) {
      animationWidget = const Icon(
        Icons.assignment_outlined,
        size: 100,
        color: Colors.grey,
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          animationWidget,
          const SizedBox(height: 16),
          const Text(
            'No tasks found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add a new task to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/task/create'),
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    return RefreshIndicator(
      onRefresh: () async {
        _loadTasks();
      },
      child: ListView.builder(
        key: _listKey,
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
            child: TaskCard(
              task: task,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/task/detail',
                  arguments: task.id,
                );
              },
              onToggleCompletion: () {
                final userId = context.read<AuthBloc>().state.userId;
                if (userId != null) {
                  context.read<TaskBloc>().add(
                        ToggleTaskCompletion(
                          taskId: task.id,
                          userId: userId,
                        ),
                      );
                }
              },
              onDelete: () => _showDeleteConfirmation(context, task),
            ),
          );
        },
      ),
    );
  }

  void _showSearch(BuildContext context) {
    final userId = context.read<AuthBloc>().state.userId;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot search: User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showSearch(
      context: context,
      delegate: TaskSearchDelegate(
        bloc: context.read<TaskBloc>(),
        userId: userId,
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      builder: (context) => const TaskFilterBottomSheet(),
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
              final userId = context.read<AuthBloc>().state.userId;
              if (userId != null) {
                context.read<TaskBloc>().add(
                      DeleteTask(
                        taskId: task.id,
                        userId: userId,
                      ),
                    );
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
