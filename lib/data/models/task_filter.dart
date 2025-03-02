enum TaskFilter {
  all,

  completed,

  incomplete,

  today,

  overdue,

  byPriority,

  search
}

extension TaskFilterExtension on TaskFilter {
  String get name {
    switch (this) {
      case TaskFilter.all:
        return 'All Tasks';
      case TaskFilter.completed:
        return 'Completed';
      case TaskFilter.incomplete:
        return 'Incomplete';
      case TaskFilter.today:
        return 'Due Today';
      case TaskFilter.overdue:
        return 'Overdue';
      case TaskFilter.byPriority:
        return 'By Priority';
      case TaskFilter.search:
        return 'Search Results';
    }
  }
}
