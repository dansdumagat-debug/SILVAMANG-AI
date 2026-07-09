import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  const PermissionService();

  Future<PermissionStatus> requestCamera() {
    return Permission.camera.request();
  }

  Future<PermissionStatus> requestLocation() {
    return Permission.locationWhenInUse.request();
  }

  Future<PermissionStatus> requestStorageIfNeeded() {
    return Permission.photos.request();
  }
}
