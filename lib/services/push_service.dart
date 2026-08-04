import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'notification_service.dart';

// Must be top-level so FCM can invoke it from the background isolate it
// spins up when the app is killed. Standard `notification`-payload messages
// are shown by the OS itself with no app code running — this only exists
// as the required registration point for any future data-only messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushService {
  PushService._();
  static final PushService instance = PushService._();

  Future<void> init() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();

    // Foreground messages don't auto-show a system notification, so route
    // them through the same local-notification path AppProvider's WS
    // listener uses.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        NotificationService.instance.show(
          notification.title ?? 'StudEx',
          notification.body ?? '',
        );
      }
    });
  }

  Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  void onTokenRefresh(void Function(String token) onToken) {
    FirebaseMessaging.instance.onTokenRefresh.listen(onToken);
  }
}
