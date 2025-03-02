import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../blocs/tasks/task_bloc.dart';
import '../../../blocs/tasks/task_event.dart';
import '../../../blocs/tasks/task_state.dart';
import '../../../data/models/task.dart';
import '../../widgets/tasks/task_card.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late CalendarFormat _calendarFormat;
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _calendarFormat = CalendarFormat.month;
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_day),
            onPressed: () {
              setState(() {
                _calendarFormat = CalendarFormat.week;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_month),
            onPressed: () {
              setState(() {
                _calendarFormat = CalendarFormat.month;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      body: BlocBuilder<TaskBloc, TaskState>(
        builder: (context, state) {
          final allTasks =
              state.filteredTasks.isEmpty ? state.tasks : state.filteredTasks;

          final tasksByDate = _groupTasksByDate(allTasks);

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                startingDayOfWeek: StartingDayOfWeek.monday,
                selectedDayPredicate: (day) {
                  return isSameDay(_selectedDay, day);
                },
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  markersMaxCount: 3,
                  markerDecoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
                eventLoader: (day) {
                  final formattedDate = DateFormat('yyyy-MM-dd').format(day);
                  return tasksByDate[formattedDate] ?? [];
                },
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    _getTaskCountForDay(tasksByDate, _selectedDay),
                  ],
                ),
              ),
              const Divider(height: 24),
              Expanded(
                child: _buildTasksForSelectedDay(tasksByDate, _selectedDay),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTaskForSelectedDay(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Map<String, List<Task>> _groupTasksByDate(List<Task> tasks) {
    final Map<String, List<Task>> tasksByDate = {};

    for (final task in tasks) {
      final date = DateFormat('yyyy-MM-dd').format(task.dueDate);
      if (tasksByDate.containsKey(date)) {
        tasksByDate[date]!.add(task);
      } else {
        tasksByDate[date] = [task];
      }
    }

    return tasksByDate;
  }

  Widget _getTaskCountForDay(
      Map<String, List<Task>> tasksByDate, DateTime day) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(day);
    final tasksForDay = tasksByDate[formattedDate] ?? [];

    final completedCount = tasksForDay.where((task) => task.isCompleted).length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: tasksForDay.isEmpty
            ? Colors.grey[300]
            : completedCount == tasksForDay.length && tasksForDay.isNotEmpty
                ? Colors.green
                : Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$completedCount/${tasksForDay.length} Tasks',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTasksForSelectedDay(
      Map<String, List<Task>> tasksByDate, DateTime day) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(day);
    final tasksForDay = tasksByDate[formattedDate] ?? [];

    if (tasksForDay.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.event_available,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks for ${DateFormat('MMMM d').format(day)}',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _addTaskForSelectedDay(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),
          ],
        ),
      );
    }

    tasksForDay.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return b.priority.index - a.priority.index;
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasksForDay.length,
      itemBuilder: (context, index) {
        final task = tasksForDay[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
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
            onDelete: () => _showDeleteConfirmation(context, task),
          ),
        );
      },
    );
  }

  void _addTaskForSelectedDay(BuildContext context) {
    final dueDate = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      12,
      0,
    );

    Navigator.pushNamed(
      context,
      '/task/create',
      arguments: {'prefilledDate': dueDate},
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
