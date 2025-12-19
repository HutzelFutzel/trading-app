import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'admin_seasonals_dashboard.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Admin Dashboard', style: AppTextStyles.headlineLarge),
        backgroundColor: AppColors.background,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withOpacity(0.05),
            height: 1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAdminItem(
            context,
            icon: Icons.admin_panel_settings,
            title: 'Seasonal Strategy Admin',
            subtitle: 'Manage seasonal trades',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminSeasonalsDashboard()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
        subtitle: Text(subtitle, style: AppTextStyles.bodyMedium),
        trailing: Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16),
        onTap: onTap,
      ),
    );
  }
}

