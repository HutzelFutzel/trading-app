import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/seasonal/seasonal_trades_admin_view.dart';
import 'admin_seasonal_strategy_settings_view.dart';

class AdminSeasonalsDashboard extends StatelessWidget {
  const AdminSeasonalsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Admin Seasonals Dashboard',
          style: AppTextStyles.headlineLarge,
        ),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withValues(alpha: 0.05),
            height: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            color: AppColors.textPrimary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminSeasonalStrategySettingsView(),
                ),
              );
            },
          ),
        ],
      ),
      body: const SeasonalTradesAdminView(),
    );
  }
}
