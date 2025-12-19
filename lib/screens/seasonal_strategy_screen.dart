import 'package:flutter/material.dart';
import '../widgets/seasonal/seasonal_trades_user_view.dart';
import '../widgets/seasonal/executed_trades_view.dart';
import '../theme/app_theme.dart';
import '../widgets/common/menu_icon_button.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SeasonalStrategyScreen extends StatefulWidget {
  const SeasonalStrategyScreen({super.key});

  @override
  State<SeasonalStrategyScreen> createState() => _SeasonalStrategyScreenState();
}

  class _SeasonalStrategyScreenState extends State<SeasonalStrategyScreen> {
  bool _isLoading = true;
  bool _isAdmin = false;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = await _apiService.getUser();
      if (mounted) {
        setState(() {
          _isAdmin = user.isAdmin;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to check admin status: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Tabs configuration
    // Admin gets Calendar, User does not
    final tabs = [
       const Tab(text: 'Trades'),
       const Tab(text: 'Activity'),
    ];

    final tabViews = [
       const SeasonalTradesUserView(),
       const ExecutedTradesView(), // Show open trades in Activity tab
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SvgPicture.asset(
                  'assets/brand/logo.svg',
                  width: 32,
                  height: 32,
                ),
              ),
              Text('Seasonal Strategy', style: AppTextStyles.headlineLarge),
            ],
          ),
          centerTitle: false,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          actions: [
            MenuIconButton(isAdmin: _isAdmin),
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
