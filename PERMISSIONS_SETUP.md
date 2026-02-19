# Permissions Setup Documentation

## Overview
This document explains how permissions are configured and handled in the Undiyal app.

## Android Permissions

### Manifest Permissions (AndroidManifest.xml)
The following permissions are declared in `android/app/src/main/AndroidManifest.xml`:

1. **SMS Permissions** (Runtime - Dangerous)
   - `READ_SMS` - Read transaction SMS messages
   - `RECEIVE_SMS` - Receive new SMS messages
   
2. **Notification Permission** (Runtime - Android 13+)
   - `POST_NOTIFICATIONS` - Show expense alerts

3. **Camera Permission** (Runtime - Dangerous)
   - `CAMERA` - Scan receipts

4. **Storage Permissions** (Runtime - Dangerous)
   - `READ_EXTERNAL_STORAGE` (Android 12 and below)
   - `WRITE_EXTERNAL_STORAGE` (Android 12 and below)
   - `READ_MEDIA_IMAGES` (Android 13+)

5. **Internet Permission** (Normal - Auto-granted)
   - `INTERNET` - API communication

### Runtime Permission Flow

#### Critical Permissions (Requested on First Launch)
- **SMS**: Required for automatic expense detection
- **Notifications**: Required for expense alerts

These are requested via the `PermissionRequestScreen` after user authentication.

#### On-Demand Permissions (Requested When Needed)
- **Camera**: Requested when user taps "Scan Receipt"
- **Photos**: Requested when user selects "Choose from Gallery"

These are handled automatically by the `image_picker` plugin.

## iOS Permissions

### Info.plist Descriptions
The following usage descriptions are in `ios/Runner/Info.plist`:

1. **NSCameraUsageDescription**
   - "We need access to your camera to scan receipts and add expense photos."

2. **NSPhotoLibraryUsageDescription**
   - "We need access to your photo library to attach receipt images to expenses."

## ProGuard Configuration

### ProGuard Rules (proguard-rules.pro)
Comprehensive rules are configured to prevent R8/ProGuard from stripping:

1. **Flutter Core Classes**
   - All Flutter embedding classes
   - Plugin registration classes

2. **Permission Handler Plugin**
   - All permission handler classes and interfaces
   - Prevents runtime crashes in release builds

3. **Other Plugins**
   - Flutter Local Notifications
   - Flutter SMS Inbox
   - Image Picker
   - Shared Preferences
   - Path Provider
   - Home Widget

4. **General Rules**
   - Keep annotations, signatures, inner classes
   - Keep native methods
   - Keep Android components (Activities, Services, BroadcastReceivers)

### Build Configuration
- **Debug Build**: ProGuard disabled for faster builds
- **Release Build**: ProGuard enabled with optimization

## Permission Request Implementation

### 1. App Initialization (main.dart)
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  // Initialize services WITHOUT requesting permissions
  await AppInitService.initialize();
  
  runApp(const UndiyalApp());
}
```

### 2. Authentication Gate (auth_gate.dart)
After successful authentication, checks if permissions have been requested:
- If not requested → Show `PermissionRequestScreen`
- If already requested → Navigate to home

### 3. Permission Request Screen
User-friendly UI that:
- Explains why each permission is needed
- Requests SMS and Notification permissions
- Allows users to skip (app still works with limited functionality)
- Handles permanently denied permissions by offering to open Settings

### 4. SMS Detection Initialization
After permissions are granted:
```dart
await AppInitService.initializeSmsDetection();
```

## Testing Permissions

### Debug Permission Status
Use the `PermissionChecker` utility class:

```dart
import 'package:undiyal/utils/permission_checker.dart';

// Check all permissions
await PermissionChecker.checkAllPermissions();

// Check specific permissions
bool hasSms = await PermissionChecker.hasSmsPermission();
bool hasNotif = await PermissionChecker.hasNotificationPermission();
```

### Testing on Device

1. **First Install**
   - Install app → Sign up → Permission screen appears
   - Grant/Deny permissions → Verify app behavior

2. **Permission Denial**
   - Deny permission → Verify app continues to work
   - Check that features requiring permission show appropriate messages

3. **Permanently Denied**
   - Deny permission twice → Verify "Open Settings" dialog appears
   - Verify Settings app opens correctly

4. **Release Build**
   - Build release APK: `flutter build apk --release`
   - Install and test all permission flows
   - Verify no crashes due to ProGuard stripping

## Common Issues & Solutions

### Issue: Permissions not requested in release build
**Solution**: Check ProGuard rules include permission_handler classes

### Issue: App crashes when requesting permissions
**Solution**: Ensure AndroidManifest.xml declares all permissions

### Issue: SMS permission always denied
**Solution**: 
- Check device Android version (SMS is dangerous permission)
- Verify app targets correct SDK version
- Check if permission is restricted by device policy

### Issue: Notification permission not showing on Android 12
**Solution**: POST_NOTIFICATIONS only required on Android 13+, automatically granted on 12 and below

## Best Practices

1. **Request permissions in context**: Show permission screen after authentication
2. **Explain why**: Always explain why each permission is needed
3. **Graceful degradation**: App should work (with limited features) if permissions denied
4. **Don't spam**: Only request permissions once, store the result
5. **Handle permanently denied**: Offer to open Settings if user permanently denies
6. **Test release builds**: Always test permissions in release builds with ProGuard enabled

## Files Modified

### Android
- `android/app/src/main/AndroidManifest.xml` - Permission declarations
- `android/app/proguard-rules.pro` - ProGuard rules
- `android/app/build.gradle.kts` - Build configuration

### iOS
- `ios/Runner/Info.plist` - Permission descriptions

### Flutter
- `lib/screens/permissions/permission_request_screen.dart` - Permission UI
- `lib/screens/auth/auth_gate.dart` - Permission flow integration
- `lib/services/app_init_service.dart` - Initialization logic
- `lib/services/notification_service.dart` - Notification permission handling
- `lib/services/sms_expense_service.dart` - SMS permission handling
- `lib/utils/permission_checker.dart` - Permission utility functions


Updated App Flow
Splash Screen
  └─ First launch? → NotificationListenerPermissionScreen (NEW)
  │                    • Explains why notification access is needed
  │                    • Opens Android system settings for notification listener
  │                    • Auto-detects when user returns from settings
  │                    • Skip option available
  │                    └─ AuthGate
  └─ Returning user? → AuthGate (directly)
                          ├─ No account → SignUpScreen / LoginScreen
                          ├─ !onboarded → ValuePropositionScreen (simplified, no permission logic)
                          ├─ !permissions → PermissionRequestScreen (SMS + Notifications)
                          ├─ !bankSetup → BankBalanceSetupScreen
                          └─ All done → Home
