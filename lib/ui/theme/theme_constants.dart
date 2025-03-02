import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryColor = Color(0xFF4A6572);
  static const Color accentColor = Color(0xFFF9AA33);

  static const Color lowPriorityColor = Color(0xFF8BC34A);
  static const Color mediumPriorityColor = Color(0xFFFFC107);
  static const Color highPriorityColor = Color(0xFFF44336);

  static const Color completedColor = Color(0xFF4CAF50);
  static const Color pendingColor = Color(0xFF9E9E9E);
  static const Color overdueColor = Color(0xFFE53935);

  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;
  static const Color dividerColor = Color(0xFFEEEEEE);

  static const Color primaryTextColor = Color(0xFF212121);
  static const Color secondaryTextColor = Color(0xFF757575);
  static const Color disabledTextColor = Color(0xFFBDBDBD);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryTextColor,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryTextColor,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryTextColor,
  );

  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    color: AppColors.primaryTextColor,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    color: AppColors.secondaryTextColor,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.secondaryTextColor,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );
}

class AppDimensions {
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  static const double borderRadiusS = 4.0;
  static const double borderRadiusM = 8.0;
  static const double borderRadiusL = 16.0;
  static const double borderRadiusXL = 24.0;

  static const double iconSizeS = 16.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;

  static const double elevationS = 2.0;
  static const double elevationM = 4.0;
  static const double elevationL = 8.0;
}

class AppAnimations {
  static const Duration shortDuration = Duration(milliseconds: 150);
  static const Duration mediumDuration = Duration(milliseconds: 300);
  static const Duration longDuration = Duration(milliseconds: 500);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.elasticOut;
}
