import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../screens/seasonal_strategy_settings_view.dart';
import '../../screens/account_screen.dart';
import '../../screens/admin_screen.dart';
import '../../services/auth_service.dart';

class MenuIconButton extends StatelessWidget {
  final bool isAdmin;

  const MenuIconButton({super.key, this.isAdmin = false});

  Future<void> _logout(BuildContext context) async {
    try {
      await AuthService().signOut();
      if (context.mounted) {
        // Pop all routes until we get back to the root (AuthWrapper)
        // AuthWrapper will automatically handle showing the SignInScreen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          elevation: 10,
          textStyle: AppTextStyles.bodyMedium,
        ),
      ),
      child: PopupMenuButton<String>(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceHighlight.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: const Icon(Icons.settings, color: AppColors.textSecondary, size: 20),
        ),
        offset: const Offset(0, 50),
        itemBuilder: (BuildContext context) {
          final userEmail = AuthService().currentUser?.email;
          
          return [
            if (userEmail != null) ...[
              PopupMenuItem<String>(
                enabled: false,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Signed in as',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
            ],
            _buildMenuItem(
              value: 'seasonal',
              icon: Icons.calendar_month,
              label: 'Seasonals Settings',
            ),
            _buildMenuItem(
              value: 'account',
              icon: Icons.manage_accounts,
              label: 'Trading Account Settings',
            ),
            if (isAdmin)
              _buildMenuItem(
                value: 'admin',
                icon: Icons.admin_panel_settings,
                label: 'Admin Panel',
                iconColor: AppColors.primary,
                textColor: AppColors.primary,
              ),
            const PopupMenuDivider(),
            _buildMenuItem(
              value: 'signout',
              icon: Icons.logout,
              label: 'Sign Out',
              iconColor: AppColors.error,
              textColor: AppColors.error,
            ),
          ];
        },
        onSelected: (String value) {
          switch (value) {
            case 'seasonal':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SeasonalStrategySettingsView()),
              );
              break;
            case 'account':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountScreen()),
              );
              break;
            case 'admin':
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              );
              break;
            case 'signout':
              _logout(context);
              break;
          }
        },
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required IconData icon,
    required String label,
    Color? iconColor,
    Color? textColor,
  }) {
    final color = iconColor ?? AppColors.textSecondary;
    final textStyle = AppTextStyles.bodyMedium.copyWith(
      color: textColor ?? AppColors.textPrimary,
      fontWeight: textColor != null ? FontWeight.w600 : FontWeight.normal,
    );

    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}
