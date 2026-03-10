# Store Screenshots Guide — Portfiq

## Required Screenshot Sizes

### iOS (App Store Connect)

| Device | Resolution | Aspect Ratio |
|--------|-----------|--------------|
| iPhone 6.7" (15 Pro Max) | 1290 x 2796 | 9:19.5 |
| iPhone 6.5" (11 Pro Max) | 1242 x 2688 | 9:19.5 |
| iPhone 5.5" (8 Plus) | 1242 x 2208 | 9:16 |
| iPad Pro 12.9" (6th gen) | 2048 x 2732 | Optional |

- Minimum 3 screenshots per size class
- Maximum 10 screenshots per size class
- Format: PNG or JPEG, no alpha channel

### Android (Google Play Console)

| Device | Minimum Resolution |
|--------|-------------------|
| Phone | 1080 x 1920 (16:9 minimum) |
| Tablet 7" | 1200 x 1920 |
| Tablet 10" | 1600 x 2560 |

- Minimum 2 screenshots, maximum 8
- Format: PNG or JPEG
- Max file size: 8 MB each

## Recommended Screenshots (5 screens)

1. **Splash / Onboarding** — Brand impression, dark theme with Portfiq logo
2. **Feed** — Main briefing feed showing daily ETF briefings
3. **Briefing Detail** — Full AI-generated briefing with charts
4. **ETF Detail** — Individual ETF performance and analysis
5. **Settings** — Personalization and notification preferences

## Capturing Screenshots

### iOS Simulator

1. Open Xcode and launch the iOS Simulator
2. Select the target device (e.g., iPhone 15 Pro Max for 6.7")
3. Run the app:
   ```bash
   cd projects/portfiq/apps/mobile
   flutter run -d "iPhone 15 Pro Max"
   ```
4. Navigate to the desired screen
5. Capture screenshot:
   - Keyboard shortcut: Cmd + S (saves to Desktop)
   - Or: Simulator menu > File > Save Screen
   - Or CLI: `xcrun simctl io booted screenshot ~/Desktop/screenshot.png`
6. Repeat for each required device size

### Android Emulator

1. Open Android Studio AVD Manager
2. Create/launch emulator with target resolution (e.g., Pixel 7 Pro for phone)
3. Run the app:
   ```bash
   cd projects/portfiq/apps/mobile
   flutter run -d emulator-5554
   ```
4. Navigate to the desired screen
5. Capture screenshot:
   - Emulator sidebar: Click the camera icon
   - Or CLI: `adb exec-out screencap -p > ~/Desktop/screenshot.png`
6. Repeat for phone and tablet emulators

### Automated Screenshots (Optional)

For consistent, repeatable screenshots, use `integration_test` with `screenshot`:

```dart
// integration_test/screenshot_test.dart
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfiq/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture store screenshots', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Screenshot 1: Feed
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01_feed');

    // Navigate and capture more screens...
  });
}
```

Run with:
```bash
flutter test integration_test/screenshot_test.dart
```

## File Organization

```
projects/portfiq/docs/screenshots/
├── ios/
│   ├── 6.7/
│   │   ├── 01_splash.png
│   │   ├── 02_feed.png
│   │   ├── 03_briefing_detail.png
│   │   ├── 04_etf_detail.png
│   │   └── 05_settings.png
│   ├── 6.5/
│   └── 5.5/
└── android/
    ├── phone/
    ├── tablet_7/
    └── tablet_10/
```

## Checklist Before Upload

- [ ] All required size classes have screenshots
- [ ] No debug banners visible (use `--release` or set `debugShowCheckedModeBanner: false`)
- [ ] Status bar shows realistic time (set in Simulator settings)
- [ ] Screenshots show realistic/demo data, not empty states
- [ ] Text is readable at thumbnail size
- [ ] Dark theme is consistent across all screenshots
- [ ] No personally identifiable information visible
