import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  final Logger _logger;

  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  ConnectivityService({Logger? logger}) : _logger = logger ?? Logger() {
    _checkConnectivity();

    _connectivity.onConnectivityChanged.listen((results) {
      final isConnected = results.any((result) => _isConnected(result));

      _connectionStatusController.add(isConnected);
    });
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();

    final isConnected =
        results.any((result) => result != ConnectivityResult.none);
    _connectionStatusController.add(isConnected);
  }

  bool _isConnected(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }

  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();

    return results.any((result) => result != ConnectivityResult.none);
  }

  void dispose() {
    _connectionStatusController.close();
  }
}
