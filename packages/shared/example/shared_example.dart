import 'package:shared/shared.dart';

void main() {
  final notification = AppNotification(
    id: 'welcome',
    title: 'Welcome to Form Bridge',
    body: 'Your workspace is ready to go!',
    createdAt: DateTime.now().toUtc(),
  );

  print('Notification JSON: ${notification.toJson()}');
}
