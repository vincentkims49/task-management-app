import 'package:get_it/get_it.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/network/connectivity_service.dart';
import '../../data/services/storage/firebase_auth_service.dart';
import '../../data/services/storage/firestore_service.dart';
import '../../data/services/storage/local_storage_service.dart';
import '../../data/services/tasks/task_sharing_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator(LocalStorageService storageService) async {
  // Services
  getIt.registerSingleton<LocalStorageService>(storageService);
  getIt.registerSingleton<FirebaseAuthService>(FirebaseAuthService());
  getIt.registerSingleton<FirestoreService>(FirestoreService());
  getIt.registerSingleton<ConnectivityService>(ConnectivityService());

  // Repositories
  getIt.registerSingleton<UserRepository>(UserRepository());

  getIt.registerSingleton<AuthRepository>(AuthRepository(
      authService: getIt<FirebaseAuthService>(),
      userRepository: getIt<UserRepository>()));

  getIt.registerSingleton<TaskRepository>(TaskRepository(
      storageService: getIt<LocalStorageService>(),
      firestoreService: getIt<FirestoreService>(),
      connectivityService: getIt<ConnectivityService>()));

  // Other services that depend on repositories
  getIt.registerSingleton<TaskSharingService>(
      TaskSharingService(userRepository: getIt<UserRepository>()));
}
