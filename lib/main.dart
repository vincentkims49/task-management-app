import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/di/service_locator.dart';
import 'utils/notification_helper.dart';
import 'app.dart';
import 'data/services/storage/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize services
  final storageService = LocalStorageService();
  await storageService.init();
  await NotificationHelper.initialize();

  // Setup dependency injection
  await setupServiceLocator(storageService);

  runApp(const TaskManagerApp());
}
