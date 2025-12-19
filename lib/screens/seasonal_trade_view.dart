import 'dart:async';
import 'package:flutter/material.dart';
import '../models/seasonal_trade.dart';
import '../models/seasonal_strategy_user_settings.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class SeasonalTradeView extends StatefulWidget {
  final SeasonalTrade trade;
  final SeasonalStrategyUserSettings? userSettings;

  const SeasonalTradeView({super.key, required this.trade, this.userSettings});

  @override
  State<SeasonalTradeView> createState() => _SeasonalTradeViewState();
}

class _SeasonalTradeViewState extends State<SeasonalTradeView> {
  late ApiService _apiService;
  
  SeasonalStrategyUserSettings? _userSettings;
  User? _user;
  bool _isLoading = true;
  bool _showAllThreads = false;
  Timer? _debounceTimer;
  
  final List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
    
    if (widget.userSettings != null) {
      _userSettings = widget.userSettings;
      // Still need to fetch user for verification status
      _fetchData(fetchSettings: false);
    } else {
      _fetchData(fetchSettings: true);
    }
  }

  void _checkThreadVisibility() {
    if (_userSettings == null || widget.trade.id == null) return;
    final currentThread = _userSettings!.getThreadForTrade(widget.trade.id!);
    if (currentThread > 5) {
      _showAllThreads = true;
    }
  }

  Future<void> _fetchData({bool fetchSettings = true}) async {
    try {
      final futures = <Future<dynamic>>[
         _apiService.getUser(),
      ];
      if (fetchSettings) {
        futures.add(_apiService.getSeasonalStrategyUserSettings());
      }

      final results = await Future.wait(futures);
      final user = results[0] as User;
      final settings = fetchSettings ? results[1] as SeasonalStrategyUserSettings : _userSettings;

      if (mounted) {
        setState(() {
          _user = user;
          _userSettings = settings;
          _isLoading = false;
          _checkThreadVisibility();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveSettings(SeasonalStrategyUserSettings newSettings) async {
    final oldSettings = _userSettings;
    setState(() => _userSettings = newSettings);
    try {
      await _apiService.saveSeasonalStrategyUserSettings(newSettings);
    } catch (e) {
      if (mounted) {
        setState(() => _userSettings = oldSettings);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  Future<void> _updateThread(int thread) async {
    if (_userSettings == null || widget.trade.id == null) return;
    
    final tradeId = widget.trade.id!;
    final newSettings = _userSettings!.assignTradeToThread(tradeId, thread);
    
    // Optimistic Update
    final oldSettings = _userSettings;
    setState(() => _userSettings = newSettings);

    try {
      final updated = await _apiService.updateThreadAssignment(tradeId, thread);
      if (mounted) {
         setState(() => _userSettings = updated);
      }
    } catch (e) {
      if (mounted) {
         setState(() => _userSettings = oldSettings);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to save thread: $e')),
         );
      }
    }
  }

  Future<void> _setMode(bool isLive) async {
    if (_userSettings == null || widget.trade.id == null) return;
    
    // Check verification
    if (isLive) {
      if (!(_user?.alpacaLiveAccount?.verified ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live account not verified')),
        );
        return;
      }
    } else {
       if (!(_user?.alpacaPaperAccount?.verified ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paper account not verified')),
        );
        return;
      }
    }

    final tradeId = widget.trade.id!;
    var newSettings = _userSettings!;
    
    if (isLive) {
        newSettings = newSettings.toggleLive(tradeId, true);
        newSettings = newSettings.togglePaper(tradeId, false);
    } else {
        newSettings = newSettings.togglePaper(tradeId, true);
        newSettings = newSettings.toggleLive(tradeId, false);
    }
    
    await _saveSettings(newSettings);
  }

  Future<void> _unsubscribe() async {
      if (_userSettings == null || widget.trade.id == null) return;
      
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Unsubscribe?', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text('This will remove the trade from all execution lists and threads.', style: TextStyle(color: AppColors.textSecondary)),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false), 
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true), 
                  child: const Text('Unsubscribe', style: TextStyle(color: AppColors.error))
                ),
            ],
        ),
      );
      
      if (confirmed != true) return;

      final newSettings = _userSettings!.unsubscribe(widget.trade.id!);
      await _saveSettings(newSettings);
      if (mounted) Navigator.pop(context);
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 2) {
        final month = int.parse(parts[0]);
        final day = int.parse(parts[1]);
        if (month >= 1 && month <= 12) {
          return '${_months[month - 1]} $day';
        }
      }
    } catch (_) {}
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.trade.symbol, style: AppTextStyles.headlineLarge),
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
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildConfigSection(),
              const SizedBox(height: 24),
              _buildDetailsSection(),
            ],
          ),
        ),
    );
  }

  Widget _buildConfigSection() {
    if (_userSettings == null || widget.trade.id == null) return const SizedBox.shrink();

    final tradeId = widget.trade.id!;
    final currentThread = _userSettings!.getThreadForTrade(tradeId);
    final liveActive = _userSettings!.isLiveActive(tradeId);
    
    // Determine active mode
    final isLiveMode = liveActive;
    
    // Verification Status
    final paperVerified = _user?.alpacaPaperAccount?.verified ?? false;
    final liveVerified = _user?.alpacaLiveAccount?.verified ?? false;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Configuration',
                style: AppTextStyles.headlineLarge.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Execution Mode Toggle
          Text('Execution Mode', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    label: 'PAPER',
                    isActive: !isLiveMode, // If not live, assume paper (since subscribed)
                    isEnabled: paperVerified,
                    onTap: () => _setMode(false),
                    activeColor: AppColors.accent,
                  ),
                ),
                Expanded(
                  child: _buildModeButton(
                    label: 'LIVE',
                    isActive: isLiveMode,
                    isEnabled: liveVerified,
                    onTap: () => _setMode(true),
                    activeColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Thread Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Execution Thread', style: AppTextStyles.bodyMedium),
              if (!_showAllThreads && currentThread <= 5)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllThreads = true),
                  icon: const Icon(Icons.expand_more, size: 16),
                  label: const Text('More'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                )
              else if (_showAllThreads)
                TextButton.icon(
                  onPressed: () => setState(() => _showAllThreads = false),
                  icon: const Icon(Icons.expand_less, size: 16),
                  label: const Text('Less'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
                )
            ],
          ),
          const SizedBox(height: 12),
          _buildThreadGrid(currentThread),
          
          const SizedBox(height: 32),
          Divider(color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          
          // Unsubscribe
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _unsubscribe,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Unsubscribe from Trade'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isActive,
    required bool isEnabled,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive ? Border.all(color: activeColor) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isEnabled 
                ? (isActive ? activeColor : AppColors.textSecondary)
                : AppColors.textDisabled,
              fontWeight: FontWeight.bold,
              decoration: isEnabled ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThreadGrid(int currentThread) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (index) {
             final threadNum = index + 1;
             return _buildThreadItem(threadNum, currentThread);
          }),
        ),
        if (_showAllThreads) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (index) {
               final threadNum = index + 6;
               return _buildThreadItem(threadNum, currentThread);
            }),
          ),
        ]
      ],
    );
  }

  Widget _buildThreadItem(int threadNum, int currentThread) {
     final isSelected = currentThread == threadNum;
     // Use unified thread colors from AppTheme
     final color = AppTheme.threadColors[threadNum] ?? Colors.grey;

     return GestureDetector(
        onTap: () => _updateThread(threadNum),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: isSelected 
              ? Border.all(color: Colors.white, width: 2)
              : null,
            boxShadow: isSelected 
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))]
              : [],
          ),
          child: Center(
            child: Text(
              '$threadNum',
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildDetailsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trade Details', style: AppTextStyles.headlineLarge),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.trade.symbol, style: AppTextStyles.displayMedium),
                  if (widget.trade.name != null)
                    Text(
                      widget.trade.name!, 
                      style: AppTextStyles.bodyMedium,
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.trade.direction == 'Long' ? AppColors.long.withOpacity(0.1) : AppColors.short.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: widget.trade.direction == 'Long' ? AppColors.long : AppColors.short),
                ),
                child: Text(
                  widget.trade.direction.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.trade.direction == 'Long' ? AppColors.long : AppColors.short,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(
                child: _buildDateBox('Open Date', widget.trade.openDate),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDateBox('Close Date', widget.trade.closeDate),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(
                widget.trade.verifiedByApi ? Icons.verified : Icons.warning_amber,
                size: 16,
                color: widget.trade.verifiedByApi ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                widget.trade.verifiedByApi ? 'Verified by API' : 'Not Verified',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: widget.trade.verifiedByApi ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateBox(String label, String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(), 
          style: AppTextStyles.bodyMedium.copyWith(fontSize: 10, letterSpacing: 1)
        ),
        const SizedBox(height: 8),
        Text(
          _formatDate(dateStr), 
          style: AppTextStyles.headlineLarge,
        ),
      ],
    );
  }
}
