import 'package:flutter/cupertino.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_colors.dart';
import 'utils/globals.dart';

class UndiyalApp extends StatelessWidget {
  const UndiyalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Undiyal',
      theme: CupertinoThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        barBackgroundColor: AppColors.background,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.textPrimary,
          textStyle: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      navigatorKey: navigatorKey,
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}