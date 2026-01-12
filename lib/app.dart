import 'package:flutter/cupertino.dart';
import 'screens/auth/signup_screen.dart';
import 'theme/app_colors.dart';

class UndiyalApp extends StatelessWidget {
  const UndiyalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Undiyal',
      theme: const CupertinoThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        barBackgroundColor: AppColors.background,
        textTheme: CupertinoTextThemeData(
          primaryColor: AppColors.textPrimary,
          textStyle: TextStyle(color: AppColors.textPrimary),
        ),
      ),
      home: const SignUpScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}