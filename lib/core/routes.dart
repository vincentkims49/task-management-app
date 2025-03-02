import 'package:flutter/material.dart';

import '../data/models/task.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/screens/auth/register_screen.dart';
import '../ui/screens/settings/settings_screen.dart';
import '../ui/screens/tasks/task_detail_screen.dart';
import '../ui/screens/tasks/task_form_screen.dart';
import '../ui/screens/tasks/calendar_screen.dart';
import '../ui/screens/tasks/shared_tasks_screen.dart';
import '../navigation/screens/main_navigation_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String taskDetail = '/task/detail';
  static const String createTask = '/task/create';
  static const String editTask = '/task/edit';
  static const String settings = '/settings';
  static const String calendar = '/calendar';
  static const String mainNavigation = '/main';
  static const String sharedTasks = '/shared-tasks';
}

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const MainNavigationScreen());
      case AppRoutes.taskDetail:
        final taskId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: taskId),
        );
      case AppRoutes.createTask:
        final args = settings.arguments;
        if (args is Map<String, dynamic> && args.containsKey('prefilledDate')) {
          return MaterialPageRoute(
            builder: (_) => TaskFormScreen(
              prefilledDate: args['prefilledDate'] as DateTime,
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const TaskFormScreen(),
        );
      case AppRoutes.editTask:
        final task = settings.arguments as Task;
        return MaterialPageRoute(
          builder: (_) => TaskFormScreen(
            task: task,
            isEditing: true,
          ),
        );
      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );
      case AppRoutes.calendar:
        return MaterialPageRoute(
          builder: (_) => const CalendarScreen(),
        );
      case AppRoutes.mainNavigation:
        return MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        );
      case AppRoutes.sharedTasks:
        return MaterialPageRoute(
          builder: (_) => const SharedTasksScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
