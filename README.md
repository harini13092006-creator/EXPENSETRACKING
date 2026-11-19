# ExpenseTracker

Flutter expense tracking app with Firebase email/password authentication.

## Firebase Authentication

The Android Firebase app is registered as `com.expensetracker.app`, matching
the Android application ID. Its configuration is in
`android/app/google-services.json`. `lib/firebase_options.dart` now initializes
Firebase on Android, Windows, and Web from the existing project configuration,
so no `--dart-define` values are required to launch:

```powershell
flutter run -d <android-device>
```

In Firebase Console, open **Authentication > Sign-in method** and enable
**Email/Password**. For separate per-platform Firebase app registrations,
authenticate the Firebase CLI and run `flutterfire configure` for Android,
Windows, and Web; it will generate platform-specific options in
`lib/firebase_options.dart`.

The login screen supports account creation, email/password sign-in, password
reset, and Google, Apple, Facebook, and Microsoft sign-in. Firebase restores
the signed-in session on launch; sign out from Settings. In Settings, a signed-in
user can link an additional provider to the current Firebase UID.

## Social provider setup

Social sign-in code is implemented, but provider operation depends on external
OAuth configuration. The checked-in Firebase Android config currently has no
OAuth client entries, and provider credentials cannot be verified from this
workspace.

In the existing Firebase project (`expensetracking-1d98f`):

1. In **Authentication > Sign-in method**, enable Google, Apple, Facebook, and
   Microsoft. Keep Email/Password enabled. Add the deployed web domains under
   **Settings > Authorized domains**.
2. **Google:** finish the Google provider setup in Firebase. Register Android
   SHA-1/SHA-256 fingerprints (debug and release), and ensure the OAuth client
   matches `com.expensetracker.app`. Add the iOS OAuth client and its reversed
   client ID URL scheme to `ios/Runner/Info.plist` if native iOS Google login
   requires it. Web uses Firebase's popup flow and the existing `authDomain`.
3. **Apple:** configure the Apple Developer App ID, Services ID, key and return
   URL in the Apple Developer portal and Firebase. Add the Sign in with Apple
   capability to the iOS Runner target and valid web domains/return URLs.
4. **Facebook:** configure a Meta developer app and Facebook Login, set its App
   ID/secret in Firebase, and add Firebase's OAuth redirect URI to the Meta app.
   The native Facebook SDK also needs the app ID/client token and URL scheme in
   Android/iOS platform configuration as described by `flutter_facebook_auth`.
5. **Microsoft:** register an Azure app, configure its redirect URI and tenant
   audience, then enter its client ID/secret in Firebase. Add any required
   platform redirect scheme and Android signing fingerprint.

Do not commit provider secrets. App IDs/client IDs are public identifiers;
secrets belong only in provider consoles and Firebase. Android native Google
login also requires the correct SHA fingerprints. Web OAuth popup flows need
the authorized domain and provider redirect/callback URLs configured.
