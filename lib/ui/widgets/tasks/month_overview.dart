import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/task.dart';

class MonthOverview extends StatelessWidget {
  final List<Task> tasks;
  final DateTime month;
  final Function(DateTime) onDayTap;

  const MonthOverview({
    Key? key,
    required this.tasks,
    required this.month,
    required this.onDayTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(month.year, month.month);
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7;

    final tasksByDate = _groupTasksByDate(tasks);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            DateFormat('MMMM yyyy').format(month),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _WeekdayLabel('S'),
            _WeekdayLabel('M'),
            _WeekdayLabel('T'),
            _WeekdayLabel('W'),
            _WeekdayLabel('T'),
            _WeekdayLabel('F'),
            _WeekdayLabel('S'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: firstWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday) {
              return const SizedBox.shrink();
            }

            final day = index - firstWeekday + 1;
            final date = DateTime(month.year, month.month, day);
            final formattedDate = DateFormat('yyyy-MM-dd').format(date);
            final tasksForDay = tasksByDate[formattedDate] ?? [];

            return _CalendarDay(
              date: date,
              tasks: tasksForDay,
              isToday: _isToday(date),
              onTap: () => onDayTap(date),
            );
          },
        ),
      ],
    );
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
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
}

class _WeekdayLabel extends StatelessWidget {
  final String text;

  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final DateTime date;
  final List<Task> tasks;
  final bool isToday;
  final VoidCallback onTap;

  const _CalendarDay({
    required this.date,
    required this.tasks,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completedTasks = tasks.where((task) => task.isCompleted).length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color:
              isToday ? Theme.of(context).primaryColor.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: Theme.of(context).primaryColor, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              date.day.toString(),
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  tasks.length > 3 ? 3 : tasks.length,
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: index < completedTasks
                          ? Colors.green
                          : Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              if (tasks.length > 3)
                Text(
                  '+${tasks.length - 3}',
                  style: const TextStyle(fontSize: 9),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
