import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/account_data.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../widgets/account/summary_view.dart';
import '../widgets/account/portfolio_view.dart';
import '../widgets/account/orders_view.dart';
import '../widgets/common/pull_refresh_container.dart';
import '../widgets/common/menu_icon_button.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'account_screen.dart';

class AccountOption {
  final AlpacaAccount account;
  final bool isPaper;
  final String label;
  AccountOption(this.account, this.isPaper, this.label);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  // State
  AccountOption? _selectedAccountOption;
  bool _isLoading = false;
  String? _error;
  bool _isAdmin = false;
  
  late TabController _tabController;
  
  // Data
  Account? _account;
  List<Position> _positions = [];
  List<Order> _orders = [];
  
  // Accounts
  List<AccountOption> _availableAccounts = [];

  // Dependencies
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
    _loadPersistedAccount();
  }

  Future<void> _loadPersistedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('selected_account_id');
    
    // First fetch available accounts
    await _fetchAccounts();
    
    if (_availableAccounts.isNotEmpty) {
      if (savedId != null) {
        try {
          final option = _availableAccounts.firstWhere((opt) => opt.account.id == savedId);
          setState(() {
            _selectedAccountOption = option;
          });
        } catch (_) {
          setState(() {
            _selectedAccountOption = _availableAccounts.first;
          });
        }
      } else {
        setState(() {
          _selectedAccountOption = _availableAccounts.first;
        });
      }
      
      await _fetchData(isRefresh: true);
    } else {
      if (mounted && _error == null) {
        // If accounts are configured but none are enabled or valid, showing empty state
        // We'll handle this in build method
      }
    }
  }

  Future<void> _fetchAccounts() async {
    try {
      final settings = await _apiService.getUser();
      if (mounted) {
        final List<AccountOption> options = [];
        
        if (settings.alpacaPaperAccount != null && settings.alpacaPaperAccount!.apiKey.isNotEmpty && settings.alpacaPaperAccount!.apiSecret.isNotEmpty && settings.alpacaPaperAccount!.verified) {
           options.add(AccountOption(settings.alpacaPaperAccount!, true, 'Paper Trading'));
        }
        
        if (settings.alpacaLiveAccount != null && settings.alpacaLiveAccount!.apiKey.isNotEmpty && settings.alpacaLiveAccount!.apiSecret.isNotEmpty && settings.alpacaLiveAccount!.verified) {
           options.add(AccountOption(settings.alpacaLiveAccount!, false, 'Live Trading'));
        }

        setState(() {
          _availableAccounts = options;
          _isAdmin = settings.isAdmin;
          if (_availableAccounts.isNotEmpty) {
             _error = null;
          }
        });
        
        if (_selectedAccountOption != null && !_availableAccounts.any((opt) => opt.account.id == _selectedAccountOption!.account.id)) {
           if (_availableAccounts.isNotEmpty) {
             setState(() {
               _selectedAccountOption = _availableAccounts.first;
             });
             _fetchData(isRefresh: false);
           } else {
             setState(() {
               _selectedAccountOption = null;
             });
           }
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch user settings: $e');
      if (mounted && _availableAccounts.isEmpty) {
         setState(() {
            _error = "Failed to fetch accounts: ${e.toString().replaceAll('Exception: ', '')}";
         });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool isRefresh = false}) async {
    if (_selectedAccountOption == null) return;

    if (!isRefresh) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      // Just clear error if any, keep content visible
      setState(() => _error = null);
    }

    try {
      final accountType = _selectedAccountOption!.isPaper ? 'paper' : 'live';
      final accountId = _selectedAccountOption!.account.id;
      
      final results = await Future.wait([
        _apiService.getAccountSummary(accountType, accountId: accountId),
        _apiService.getPositions(accountType, accountId: accountId),
        _apiService.getOrders(accountType, accountId: accountId),
        _apiService.getTrades(accountType, accountId: accountId),
      ]);

      final account = results[0] as Account;
      final positions = results[1] as List<Position>;
      final openOrders = results[2] as List<Order>;
      final trades = results[3] as List<Order>;
      
      final allOrders = [...openOrders, ...trades];
      allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _account = account;
          _positions = positions;
          _orders = allOrders;
          _isLoading = false;
        });
        
        // Removed manual snackbar triggering here since PullRefreshContainer handles it now
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onAccountSwitch(AccountOption option) async {
    setState(() {
      _selectedAccountOption = option;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_account_id', option.account.id);
    
    _fetchData(isRefresh: false);
  }

  Future<void> _cancelOrder(Order order) async {
    if (_selectedAccountOption == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Are you sure you want to cancel the order for ${order.symbol}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final accountType = _selectedAccountOption!.isPaper ? 'paper' : 'live';
      final accountId = _selectedAccountOption!.account.id;
      
      await _apiService.cancelOrder(accountType, order.id, accountId: accountId);
      
      if (mounted) {
        setState(() {
          _orders.removeWhere((o) => o.id == order.id);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully')),
        );
        // We update locally for immediate feedback, so we don't need to force refresh
        // _fetchData(isRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel order: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _closePosition(Position position) async {
    if (_selectedAccountOption == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Position'),
        content: Text('Are you sure you want to close your position in ${position.symbol}? This will place a Market GTC order.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final accountType = _selectedAccountOption!.isPaper ? 'paper' : 'live';
      final accountId = _selectedAccountOption!.account.id;
      
      await _apiService.closePosition(accountType, position.symbol, accountId: accountId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Position close initiated')),
        );
        // Refresh to show the new closing order
        _fetchData(isRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close position: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountScreen()),
    ).then((_) => _loadPersistedAccount());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Explicitly set background
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            pinned: true,
            snap: false,
            // Ensure background color is opaque dark for scroll under
            backgroundColor: AppColors.background, 
            surfaceTintColor: Colors.transparent,
            centerTitle: false,
            title: _buildHeaderDropdown(),
            actions: [
            
              MenuIconButton(isAdmin: _isAdmin),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                  color: AppColors.background, // Ensure tab bar has background
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: Colors.transparent,
                  labelStyle: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Summary'),
                    Tab(text: 'Portfolio'),
                    Tab(text: 'Orders'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Container(
          color: AppColors.background, // Ensure body background is dark
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _availableAccounts.isEmpty 
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.primary),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Configure Trading',
                          style: AppTextStyles.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'To start trading, please configure and enable at least one account (Paper or Live).',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          onPressed: _navigateToSettings,
                          icon: const Icon(Icons.settings),
                          label: const Text('Go to Settings'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            textStyle: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _error != null 
                ? Center(
                    child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _loadPersistedAccount,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    PullRefreshContainer(
                      onRefresh: _loadPersistedAccount,
                      child: SummaryView(
                        account: _account,
                        positions: _positions,
                        recentOrders: _orders.take(5).toList(),
                        accountType: (_selectedAccountOption?.isPaper ?? true) ? 'paper' : 'live',
                        onCancelOrder: _cancelOrder,
                      ),
                    ),
                    PullRefreshContainer(
                      onRefresh: _loadPersistedAccount,
                      child: PortfolioView(
                        positions: _positions,
                        onClosePosition: _closePosition,
                      ),
                    ),
                    PullRefreshContainer(
                      onRefresh: _loadPersistedAccount,
                      child: OrdersView(
                        orders: _orders,
                        onCancelOrder: _cancelOrder,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderDropdown() {
    if (_availableAccounts.isEmpty) {
      return Text('Account Dashboard', style: AppTextStyles.headlineLarge);
    }

    final current = _selectedAccountOption ?? _availableAccounts.first;

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SvgPicture.asset(
              'assets/brand/logo.svg',
              width: 32,
              height: 32,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trading Account',
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 10, color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  Text(
                    current.label,
                    style: AppTextStyles.headlineLarge.copyWith(fontSize: 16),
                  ),
                  Icon(Icons.arrow_drop_down, size: 20, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ],
      ),
      itemBuilder: (context) => _availableAccounts.map((option) {
        return _buildPopupItem(option);
      }).toList(),
      onSelected: (id) {
        final option = _availableAccounts.firstWhere((opt) => opt.account.id == id);
        _onAccountSwitch(option);
      },
    );
  }

  PopupMenuItem<String> _buildPopupItem(AccountOption option) {
    final idDisplay = option.account.id.split('-').last;
    final isPaper = option.isPaper;
    
    return PopupMenuItem(
      value: option.account.id,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isPaper ? AppColors.accent : AppColors.error).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: (isPaper ? AppColors.accent : AppColors.error).withOpacity(0.3))
            ),
            child: Text(
              isPaper ? 'PAPER' : 'LIVE', 
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.bold, 
                color: isPaper ? AppColors.accent : AppColors.error
              )
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              option.label, 
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500)
            ),
          ),
          const SizedBox(width: 8),
          Text(
            idDisplay,
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 12, color: AppColors.textDisabled),
          ),
        ],
      ),
    );
  }
}
