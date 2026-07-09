import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  const ConnectivityService();

  Future<dynamic> checkConnection() {
    return Connectivity().checkConnectivity();
  }
}
