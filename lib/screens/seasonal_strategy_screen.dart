import 'package:flutter/material.dart';
import '../widgets/seasonal/seasonal_trades_user_view.dart';
import 'seasonal_strategy_settings_view.dart';
import '../widgets/seasonal/executed_trades_view.dart';
import '../theme/app_theme.dart';

class SeasonalStrategyScreen extends StatefulWidget {
  const SeasonalStrategyScreen({super.key});

  @override
  State<SeasonalStrategyScreen> createState() => _SeasonalStrategyScreenState();
}

  class _SeasonalStrategyScreenState extends State<SeasonalStrategyScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    setState(() => _isLoading = false);
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SeasonalStrategySettingsView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Tabs configuration
    // Admin gets Calendar, User does not
    final tabs = [
       const Tab(text: 'Trades'),
       const Tab(text: 'Performance'),
       const Tab(text: 'Activity'),
    ];

    final tabViews = [
       const SeasonalTradesUserView(),
       const Center(child: Text('Performance Placeholder')),
       const ExecutedTradesView(), // Show open trades in Activity tab
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Seasonal Strategy', style: AppTextStyles.headlineLarge),
          centerTitle: false,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              color: AppColors.textSecondary,
              onPressed: _openSettings,
              tooltip: 'Strategy Rules',
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                color: AppColors.background,
              ),
              child: TabBar(
                tabs: tabs,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        body: TabBarView(children: tabViews),
      ),
    );
  }
}
