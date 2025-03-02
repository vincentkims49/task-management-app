import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as theme;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/tasks/task_bloc.dart';
import '../blocs/theme/theme_bloc.dart';
import '../blocs/theme/theme_event.dart';
import '../blocs/theme/theme_state.dart';
import '../core/di/service_locator.dart';
import '../core/routes.dart';
import '../navigation/auth_wrapper.dart';
import '../ui/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/services/tasks/task_sharing_service.dart';

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeBloc>(
          create: (context) => ThemeBloc()..add(const ThemeInitialized()),
        ),
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
              authRepository: getIt<AuthRepository>(),
              taskRepository: getIt<TaskRepository>())
            ..add(const AppStarted()),
        ),
        BlocProvider<TaskBloc>(
          create: (context) =>
              TaskBloc(taskRepository: getIt<TaskRepository>()),
        ),
      ],
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: getIt<TaskRepository>()),
          RepositoryProvider.value(value: getIt<UserRepository>()),
          RepositoryProvider.value(value: getIt<TaskSharingService>()),
        ],
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            return MaterialApp(
              title: 'Task Manager',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeState.isDarkMode
                  ? theme.ThemeMode.dark
                  : theme.ThemeMode.light,
              onGenerateRoute: AppRouter.generateRoute,
              home: const AuthenticationWrapper(),
            );
          },
        ),
      ),
    );
  }
}
