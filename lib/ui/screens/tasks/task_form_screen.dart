import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../blocs/auth/auth_bloc.dart';

import '../../../blocs/tasks/task_bloc.dart';
import '../../../blocs/tasks/task_event.dart';
import '../../../blocs/tasks/task_state.dart';
import '../../../data/models/task.dart';
import '../../../data/models/subtask.dart';
import '../../theme/theme_constants.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/tasks/priority_selector.dart';
import '../../widgets/tasks/subtask_list.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? task;
  final bool isEditing;
  final DateTime? prefilledDate;

  const TaskFormScreen({
    Key? key,
    this.task,
    this.isEditing = false,
    this.prefilledDate,
  }) : super(key: key);

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subtaskController = TextEditingController();

  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _dueTime = TimeOfDay.now();
  TaskPriority _priority = TaskPriority.medium;
  List<Subtask> _subtasks = [];

  bool _isNavigating = false;

  bool get _isEditing => widget.isEditing;

  @override
  void initState() {
    super.initState();

    if (_isEditing && widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _dueDate = widget.task!.dueDate;
      _dueTime = TimeOfDay.fromDateTime(widget.task!.dueDate);
      _priority = widget.task!.priority;
      _subtasks = List.from(widget.task!.subtasks);
    } else if (widget.prefilledDate != null) {
      _dueDate = widget.prefilledDate!;
      _dueTime = TimeOfDay.fromDateTime(widget.prefilledDate!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'Create Task'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: BlocListener<TaskBloc, TaskState>(
        listenWhen: (previous, current) {
          return !_isNavigating &&
              previous.status == TaskStatus.loading &&
              current.status == TaskStatus.success &&
              current.lastCreatedTaskId != null &&
              current.lastCreatedTaskId != previous.lastCreatedTaskId;
        },
        listener: (context, state) {
          if (state.status == TaskStatus.success &&
              state.lastCreatedTaskId != null &&
              state.lastCreatedTaskId!.isNotEmpty) {
            _isNavigating = true;

            print(
                'Navigating to newly created task with ID: ${state.lastCreatedTaskId}');

            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                Navigator.pushNamed(
                  context,
                  '/task/detail',
                  arguments: state.lastCreatedTaskId,
                );
              }
            });
          } else if (state.status == TaskStatus.failure &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            children: [
              CustomTextField(
                controller: _titleController,
                labelText: 'Title',
                hintText: 'Enter task title',
                prefixIcon: const Icon(Icons.title),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.paddingM),
              CustomTextField(
                controller: _descriptionController,
                labelText: 'Description',
                hintText: 'Enter task description',
                prefixIcon: const Icon(Icons.description),
                maxLines: 3,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Due Date',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_dueDate),
                        ),
                        onTap: _selectDueDate,
                      ),
                      ListTile(
                        leading: const Icon(Icons.access_time),
                        title: Text(
                          _dueTime.format(context),
                        ),
                        onTap: _selectDueTime,
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
                        'Priority',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppDimensions.paddingS),
                      PrioritySelector(
                        selectedPriority: _priority,
                        onChanged: (priority) {
                          setState(() {
                            _priority = priority;
                          });
                        },
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
                        'Subtasks',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppDimensions.paddingS),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _subtaskController,
                              labelText: 'Subtask',
                              hintText: 'Enter subtask',
                              prefixIcon:
                                  const Icon(Icons.check_circle_outline),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: _addSubtask,
                            color: AppColors.primaryColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.paddingM),
                      SubtaskList(
                        subtasks: _subtasks,
                        onDelete: (index) {
                          setState(() {
                            _subtasks.removeAt(index);
                          });
                        },
                        onToggle: (index) {
                          setState(() {
                            final subtask = _subtasks[index];
                            _subtasks[index] = subtask.copyWith(
                              isCompleted: !subtask.isCompleted,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),
              BlocBuilder<TaskBloc, TaskState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status,
                builder: (context, state) {
                  return ElevatedButton(
                    onPressed:
                        state.status == TaskStatus.loading ? null : _saveTask,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.paddingM,
                      ),
                    ),
                    child: state.status == TaskStatus.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? 'UPDATE TASK' : 'CREATE TASK'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _dueDate = date;
      });
    }
  }

  Future<void> _selectDueTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _dueTime,
    );

    if (time != null) {
      setState(() {
        _dueTime = time;
      });
    }
  }

  void _addSubtask() {
    final title = _subtaskController.text.trim();
    if (title.isNotEmpty) {
      setState(() {
        _subtasks.add(Subtask.create(title: title));
        _subtaskController.clear();
      });
    }
  }

  void _saveTask() {
    if (_formKey.currentState?.validate() ?? false) {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();

      final dueDateTime = DateTime(
        _dueDate.year,
        _dueDate.month,
        _dueDate.day,
        _dueTime.hour,
        _dueTime.minute,
      );

      final userId = context.read<AuthBloc>().state.userId;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be logged in to create tasks'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_isEditing && widget.task != null) {
        final updatedTask = widget.task!.copyWith(
          title: title,
          description: description,
          dueDate: dueDateTime,
          priority: _priority,
          subtasks: _subtasks,
        );

        context.read<TaskBloc>().add(UpdateTask(task: updatedTask));
        context.read<TaskBloc>().add(LoadTasks(userId: userId));

        Navigator.pop(context);
      } else {
        final TaskBloc bloc = context.read<TaskBloc>();

        _isNavigating = true;

        void onTaskCreated(String taskId) {
          if (mounted) {
            print('Direct navigation to task detail for task ID: $taskId');
            Navigator.pushReplacementNamed(
              context,
              '/task/detail',
              arguments: taskId,
            );
            context.read<TaskBloc>().add(LoadTasks(userId: userId));
          }
        }

        bloc.createTaskWithCallback(
          title: title,
          description: description,
          dueDate: dueDateTime,
          priority: _priority,
          userId: userId,
          subtasks: _subtasks,
          onSuccess: onTaskCreated,
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    if (widget.task == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content:
            Text('Are you sure you want to delete "${widget.task!.title}"?'),
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
                        taskId: widget.task!.id,
                        userId: userId,
                      ),
                    );
                context.read<TaskBloc>().add(LoadTasks(userId: userId));

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
