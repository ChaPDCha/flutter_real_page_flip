import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBfnV-hBzlsWuln3d_64TEJ6lQiJxWvcME',
    appId: '1:759272528237:android:7aa8eb768bb5e376b7e264',
    messagingSenderId: '759272528237',
    projectId: 'realbook-499611-b2d02',
    storageBucket: 'realbook-499611-b2d02.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform => android;
}
