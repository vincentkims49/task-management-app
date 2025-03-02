import 'package:flutter/material.dart';

import '../../../../data/models/task.dart';
import '../../../../data/models/task_filter.dart';

import '../../../blocs/tasks/task_bloc.dart';
import '../../../blocs/tasks/task_event.dart';
import '../../screens/tasks/task_detail_screen.dart';
import '../../theme/theme_constants.dart';
import 'task_card.dart';

class TaskSearchDelegate extends SearchDelegate<String> {
  final TaskBloc bloc;
  final String userId;

  TaskSearchDelegate({
    required this.bloc,
    required this.userId,
  });

  @override
  String get searchFieldLabel => 'Search tasks...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Text('Please enter a search term'),
      );
    }

    bloc.add(
      FilterTasks(
        userId: userId,
        filter: TaskFilter.search,
        searchQuery: query,
      ),
    );

    return FutureBuilder<List<Task>>(
      future: bloc.state.tasks.isNotEmpty
          ? Future.value(bloc.state.filteredTasks)
          : Future.delayed(
              const Duration(milliseconds: 300),
              () => bloc.state.filteredTasks,
            ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.search_off,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: AppDimensions.paddingM),
                Text(
                  'No tasks found for "$query"',
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
              child: TaskCard(
                task: task,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailScreen(
                        taskId: task.id,
                      ),
                    ),
                  );
                },
                onToggleCompletion: () {
                  bloc.add(
                    ToggleTaskCompletion(
                      taskId: task.id,
                      userId: userId,
                    ),
                  );
                },
                onDelete: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Task'),
                      content: Text(
                          'Are you sure you want to delete "${task.title}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            bloc.add(
                              DeleteTask(
                                taskId: task.id,
                                userId: userId,
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
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: AppDimensions.paddingM),
            const Text(
              'Search for tasks by title or description',
              style: AppTextStyles.body1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.paddingL),
            Wrap(
              spacing: AppDimensions.paddingS,
              children: [
                _buildSearchChip(context, 'Today'),
                _buildSearchChip(context, 'High priority'),
                _buildSearchChip(context, 'Meeting'),
                _buildSearchChip(context, 'Deadline'),
              ],
            ),
          ],
        ),
      );
    }

    return buildResults(context);
  }

  Widget _buildSearchChip(BuildContext context, String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        query = label;
        showResults(context);
      },
    );
  }
}
