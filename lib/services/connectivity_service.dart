import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return !results.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map((results) {
          try {
            return !results.contains(ConnectivityResult.none);
          } catch (_) {
            return false;
          }
        })
        .handleError((_) => false)
        .distinct();
  }
}
