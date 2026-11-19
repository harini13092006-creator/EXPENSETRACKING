import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:expensetracker/core/constants/app_colors.dart';
import 'package:expensetracker/core/constants/app_constants.dart';
import 'package:expensetracker/features/dashboard/screens/main_nav_screen.dart';
import 'package:expensetracker/features/splash/screens/splash_screen.dart';
import 'package:expensetracker/providers/dashboard_provider.dart';
import 'package:expensetracker/providers/theme_provider.dart';

void main() {
  group('Branding & Splash Screen Tests', () {
    testWidgets('SplashScreen renders application icon, app name, and emerald branding', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(autoNavigate: false),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Verify Application Name
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('ExpenseTracker'), findsOneWidget);

      // 2. Verify Tagline
      expect(find.text('Smart Financial & Budget Tracking'), findsOneWidget);

      // 3. Verify Progress Indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 4. Verify Theme color (Emerald background)
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(AppColors.primary));
    });

    testWidgets('SplashScreen auto-navigates smoothly to MainNavScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ],
          child: const MaterialApp(
            home: SplashScreen(
              autoNavigate: true,
              duration: Duration(milliseconds: 100),
            ),
          ),
        ),
      );

      // Initially on Splash
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.byType(SplashScreen), findsOneWidget);

      // Advance timer and transition
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Navigated to MainNavScreen
      expect(find.byType(MainNavScreen), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);
    });

    test('Verify Android and iOS launcher icon assets exist on disk', () {
      // 1. Check source master icon
      final masterIcon = File('assets/icons/app_icon.png');
      expect(masterIcon.existsSync(), isTrue);
      expect(masterIcon.lengthSync(), greaterThan(1000));

      // 2. Check Android mipmaps
      final androidMipmaps = [
        'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
        'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      ];
      for (final path in androidMipmaps) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: '$path must exist');
        expect(f.lengthSync(), greaterThan(500));
      }

      // 3. Check iOS AppIcon set
      final iosAppIcons = [
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      ];
      for (final path in iosAppIcons) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: '$path must exist');
        expect(f.lengthSync(), greaterThan(500));
      }

      // 4. Check native splash drawables
      final androidSplashDrawables = [
        'android/app/src/main/res/drawable/launch_background.xml',
        'android/app/src/main/res/drawable-night/launch_background.xml',
      ];
      for (final path in androidSplashDrawables) {
        final f = File(path);
        expect(f.existsSync(), isTrue, reason: '$path must exist');
      }
    });
  });
}
