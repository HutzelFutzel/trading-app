import 'dart:async';
import 'package:flutter/material.dart';
import '../models/seasonal_trade.dart';
import '../models/seasonal_strategy_user_settings.dart';
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
      _isLoading = false;
      _checkThreadVisibility();
    } else {
      _fetchSettings();
    }
  }

  void _checkThreadVisibility() {
    if (_userSettings == null || widget.trade.id == null) return;
    final currentThread = _userSettings!.getThreadForTrade(widget.trade.id!);
    if (currentThread > 5) {
      _showAllThreads = true;
    }
  }

  Future<void> _fetchSettings() async {
    try {
      final settings = await _apiService.getSeasonalStrategyUserSettings();
      if (mounted) {
        setState(() {
          _userSettings = settings;
          _isLoading = false;
          _checkThreadVisibility();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _updateSetting({bool? paper, bool? live, int? thread}) async {
    if (_userSettings == null || widget.trade.id == null) return;
    
    final tradeId = widget.trade.id!;
    
    // Optimistic Update
    var newSettings = _userSettings!;
    if (paper != null) newSettings = newSettings.togglePaper(tradeId, paper);
    if (live != null) newSettings = newSettings.toggleLive(tradeId, live);
    if (thread != null) newSettings = newSettings.assignTradeToThread(tradeId, thread);

    final oldSettings = _userSettings;
    setState(() => _userSettings = newSettings);

    try {
      if (thread != null) {
        final updated = await _apiService.updateThreadAssignment(tradeId, thread);
        if (mounted) {
           setState(() => _userSettings = updated);
        }
      } else {
        await _apiService.saveSeasonalStrategyUserSettings(newSettings);
      }
    } catch (e) {
      if (mounted) {
         setState(() => _userSettings = oldSettings);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Failed to save settings: $e')),
         );
      }
    }
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
    final paperActive = _userSettings!.isPaperActive(tradeId);
    final liveActive = _userSettings!.isLiveActive(tradeId);

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
          
          const SizedBox(height: 24),
          Divider(color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 8),

          // Switches
          _buildSwitchRow(
            'Paper Trading', 
            'Simulated execution',
            paperActive,
            (val) => _updateSetting(paper: val),
            AppColors.accent,
          ),
          _buildSwitchRow(
            'Live Trading', 
            'Real money execution',
            liveActive,
            (val) => _updateSetting(live: val),
            AppColors.error,
          ),
        ],
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
        onTap: () => _updateSetting(thread: threadNum),
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

  Widget _buildSwitchRow(
    String title, 
    String subtitle, 
    bool value, 
    Function(bool) onChanged,
    Color activeColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              Text(subtitle, style: AppTextStyles.bodyMedium),
            ],
          ),
          Switch(
            value: value, 
            onChanged: onChanged,
            activeColor: activeColor,
            activeTrackColor: activeColor.withOpacity(0.3),
            inactiveThumbColor: AppColors.textDisabled,
            inactiveTrackColor: Colors.black.withOpacity(0.2),
          ),
        ],
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
