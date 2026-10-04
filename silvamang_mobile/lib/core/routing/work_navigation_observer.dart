import 'package:flutter/material.dart';

/// Keeps existing form routes alive while another feature is opened on top.
class WorkNavigationObserver extends NavigatorObserver with ChangeNotifier {
  final List<Route<dynamic>> _routes = [];
  static const workRoutes = {
    'captureGuide',
    'manualSpeciesMeasurement',
    'identificationResult',
    'measurement',
    'cameraPointingMeasurement',
    'locationValidation',
    'transectCreate',
  };

  bool get isWorking =>
      _routes.isNotEmpty && workRoutes.contains(_routes.last.settings.name);

  Route<dynamic>? get unfinishedRoute {
    if (_routes.isNotEmpty && workRoutes.contains(_routes.last.settings.name)) {
      return null;
    }
    for (final route in _routes.reversed.skip(1)) {
      if (workRoutes.contains(route.settings.name)) return route;
    }
    return null;
  }

  bool resume() {
    final target = unfinishedRoute;
    if (target == null || navigator == null) return false;
    navigator!.popUntil((route) => identical(route, target));
    return true;
  }

  void _changed() {
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _changed();
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
  }
}

final workNavigationObserver = WorkNavigationObserver();
