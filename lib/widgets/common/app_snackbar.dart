import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppSnackBar extends SnackBar {
  AppSnackBar({
    super.key,
    required String message,
    super.duration = const Duration(seconds: 2),
    IconData? icon,
    Color? iconColor,
  }) : super(
          content: Row(
            children: [
              Icon(
                icon ?? Icons.check_circle_outline,
                color: iconColor ?? AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );
}
