import 'package:flutter/material.dart';

/// App-wide navigator key so non-widget code (providers reacting to WebSocket
/// events) can navigate — e.g. auto-opening the Ride screen when a new order
/// offer arrives while the driver is elsewhere in the app.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Name of the route currently on top, maintained by [routeObserver]. Used to
/// avoid pushing a duplicate '/ride' when the driver is already there.
String? currentRouteName;

class _RouteTracker extends NavigatorObserver {
  void _set(Route<dynamic>? route) => currentRouteName = route?.settings.name;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(previousRoute);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _set(newRoute);
}

final NavigatorObserver routeObserver = _RouteTracker();
