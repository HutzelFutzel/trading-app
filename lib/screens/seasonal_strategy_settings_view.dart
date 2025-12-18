import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/seasonal_strategy_user_settings.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class SeasonalStrategySettingsView extends StatefulWidget {
  const SeasonalStrategySettingsView({super.key});

  @override
  State<SeasonalStrategySettingsView> createState() => _SeasonalStrategySettingsViewState();
}

class _SeasonalStrategySettingsViewState extends State<SeasonalStrategySettingsView> {
  final ApiService _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Data
  SeasonalStrategyUserSettings? _userRules;
  List<int> _availableThreads = [];

  // Local State for Edit
  late bool _enablePaperTrading;
  late bool _enableLiveTrading;
  late String _allocationMode;
  late Map<int, double> _customAllocations;
  late double _maxMargin;
  late bool _allowThreadOverlap;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _apiService.getSeasonalStrategyUserSettings(),
      ]);

      _userRules = results[0];

      _initLocalState();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load settings: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _initLocalState() {
    if (_userRules == null) return;

    // Threads Logic
    // Always show 10 threads
    _availableThreads = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

    // User Settings
    _enablePaperTrading = _userRules!.enablePaperTrading;
    _enableLiveTrading = _userRules!.enableLiveTrading;
    _allocationMode = _userRules!.allocationMode;
    _customAllocations = Map.from(_userRules!.customAllocations);
    _maxMargin = _userRules!.maxMargin;
    _allowThreadOverlap = _userRules!.allowThreadOverlap;

    // Defaults for allocation if missing
    if (_customAllocations.isEmpty) {
      final share = 100.0 / _availableThreads.length;
      for (var t in _availableThreads) {
        _customAllocations[t] = share;
      }
    }
  }

  // --- Logic Helpers ---

  List<String> _getTradeIdsForThread(int threadId) {
    switch (threadId) {
      case 1: return _userRules!.thread1;
      case 2: return _userRules!.thread2;
      case 3: return _userRules!.thread3;
      case 4: return _userRules!.thread4;
      case 5: return _userRules!.thread5;
      case 6: return _userRules!.thread6;
      case 7: return _userRules!.thread7;
      case 8: return _userRules!.thread8;
      case 9: return _userRules!.thread9;
      case 10: return _userRules!.thread10;
      default: return [];
    }
  }

  bool _isThreadPaperActive(int threadId) {
    final tradeIds = _getTradeIdsForThread(threadId);
    if (tradeIds.isEmpty) return false;
    return tradeIds.every((id) => _userRules!.paperTradeIds.contains(id));
  }

  bool _isThreadLiveActive(int threadId) {
    final tradeIds = _getTradeIdsForThread(threadId);
    if (tradeIds.isEmpty) return false;
    return tradeIds.every((id) => _userRules!.liveTradeIds.contains(id));
  }

  Future<void> _toggleThreadPaper(int threadId, bool isActive) async {
    final tradeIds = _getTradeIdsForThread(threadId);
    final currentList = List<String>.from(_userRules!.paperTradeIds);
    
    if (isActive) {
      for (var id in tradeIds) {
        if (!currentList.contains(id)) currentList.add(id);
      }
    } else {
      for (var id in tradeIds) {
        currentList.remove(id);
      }
    }

    final newUserRules = _userRules!.copyWith(paperTradeIds: currentList);
    await _saveUserRules(newUserRules);
  }

  Future<void> _toggleThreadLive(int threadId, bool isActive) async {
    final tradeIds = _getTradeIdsForThread(threadId);
    final currentList = List<String>.from(_userRules!.liveTradeIds);
    
    if (isActive) {
      for (var id in tradeIds) {
        if (!currentList.contains(id)) currentList.add(id);
      }
    } else {
      for (var id in tradeIds) {
        currentList.remove(id);
      }
    }

    final newUserRules = _userRules!.copyWith(liveTradeIds: currentList);
    await _saveUserRules(newUserRules);
  }

  Future<void> _saveUserRules(SeasonalStrategyUserSettings newRules) async {
    setState(() => _isSaving = true);
    try {
      await _apiService.saveSeasonalStrategyUserSettings(newRules);
      setState(() {
        _userRules = newRules;
        _isSaving = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e', style: const TextStyle(color: Colors.white))));
      }
    }
  }
  
  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Strategy Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Seasonal Strategy Settings')),
        body: Center(child: Text(_error!, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error))),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Seasonal Strategy Settings', style: AppTextStyles.headlineLarge),
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
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEnvironmentSection(),
            const SizedBox(height: 24),
            _buildThreadsSection(),
            const SizedBox(height: 24),
            _buildRiskSection(),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ENVIRONMENT',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMasterToggle(
                'Paper Trading',
                'Simulated execution',
                AppColors.accent,
                _enablePaperTrading,
                (val) {
                  setState(() => _enablePaperTrading = val);
                  _saveUserRules(_userRules!.copyWith(enablePaperTrading: val));
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMasterToggle(
                'Live Trading',
                'Real capital execution',
                AppColors.error,
                _enableLiveTrading,
                (val) {
                  setState(() => _enableLiveTrading = val);
                  _saveUserRules(_userRules!.copyWith(enableLiveTrading: val));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMasterToggle(String title, String subtitle, Color color, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                title.contains('Paper') ? Icons.assignment_outlined : Icons.bolt,
                color: value ? color : AppColors.textSecondary,
              ),
              Switch(
                value: value, 
                onChanged: onChanged,
                activeColor: color,
                activeTrackColor: color.withOpacity(0.3),
                inactiveTrackColor: AppColors.surfaceHighlight.withOpacity(0.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.headlineLarge.copyWith(fontSize: 16)),
          Text(subtitle, style: AppTextStyles.bodyMedium.copyWith(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildThreadsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(
              'THREAD CONFIGURATION',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            // Allocation Mode Toggle
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeButton('Equal', _allocationMode == 'equal', () {
                    setState(() => _allocationMode = 'equal');
                    // Reset custom allocations to equal
                    final share = 100.0 / _availableThreads.length;
                    final newAlloc = { for (var t in _availableThreads) t: share };
                    setState(() => _customAllocations = newAlloc);
                    _saveUserRules(_userRules!.copyWith(allocationMode: 'equal', customAllocations: newAlloc));
                  }),
                  const SizedBox(width: 4),
                  _buildModeButton('Custom', _allocationMode == 'custom', () {
                     setState(() => _allocationMode = 'custom');
                     _saveUserRules(_userRules!.copyWith(allocationMode: 'custom'));
                  }),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availableThreads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final threadId = _availableThreads[index];
            return _buildThreadCard(threadId);
          },
        ),
      ],
    );
  }

  Widget _buildModeButton(String text, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isSelected ? BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(6),
        ) : null,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildThreadCard(int threadId) {
    final threadColor = AppTheme.threadColors[threadId] ?? Colors.grey;
    final isPaper = _isThreadPaperActive(threadId);
    final isLive = _isThreadLiveActive(threadId);
    final allocation = _customAllocations[threadId] ?? 0;
    final tradeCount = _getTradeIdsForThread(threadId).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Thread Indicator
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: threadColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: threadColor.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                '$threadId',
                style: TextStyle(color: threadColor, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thread $threadId', style: AppTextStyles.headlineLarge.copyWith(fontSize: 16)),
                Text('$tradeCount Trades Assigned', style: AppTextStyles.bodyMedium.copyWith(fontSize: 12)),
              ],
            ),
          ),

          // Controls
          Row(
            children: [
              // Paper Toggle
              Column(
                children: [
                  Text('PAPER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accent)),
                  Switch(
                    value: isPaper,
                    onChanged: (v) => _toggleThreadPaper(threadId, v),
                    activeColor: AppColors.accent,
                    activeTrackColor: AppColors.accent.withOpacity(0.3),
                    inactiveTrackColor: AppColors.surfaceHighlight.withOpacity(0.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Live Toggle
              Column(
                children: [
                  Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error)),
                  Switch(
                    value: isLive,
                    onChanged: (v) => _toggleThreadLive(threadId, v),
                    activeColor: AppColors.error,
                    activeTrackColor: AppColors.error.withOpacity(0.3),
                    inactiveTrackColor: AppColors.surfaceHighlight.withOpacity(0.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Allocation
              SizedBox(
                width: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('ALLOC', style: AppTextStyles.bodyMedium.copyWith(fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (_allocationMode == 'equal')
                      Text('${allocation.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))
                    else
                      _buildNumberInput(
                        value: allocation, 
                        suffix: '%', 
                        onChanged: (val) {
                          // Validate sum
                          double sum = 0;
                          _customAllocations.forEach((k, v) { if(k != threadId) sum += v; });
                          if (sum + val <= 100.1) { // tolerance
                             final newAlloc = Map<int, double>.from(_customAllocations);
                             newAlloc[threadId] = val;
                             setState(() => _customAllocations = newAlloc);
                             _saveUserRules(_userRules!.copyWith(customAllocations: newAlloc));
                          }
                        }
                      ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRiskSection() {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RISK MANAGEMENT',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                     const Icon(Icons.security, color: AppColors.primary),
                     const SizedBox(width: 16),
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text('Max Margin Utilization', style: AppTextStyles.headlineLarge.copyWith(fontSize: 16)),
                           Text('Limit leverage across all trades', style: AppTextStyles.bodyMedium.copyWith(fontSize: 12)),
                         ],
                       ),
                     ),
                     SizedBox(
                       width: 80,
                       child: _buildNumberInput(
                         value: _maxMargin,
                         suffix: '%',
                         onChanged: (val) {
                           if (val >= 0 && val <= 100) {
                             setState(() => _maxMargin = val);
                             _saveUserRules(_userRules!.copyWith(maxMargin: val));
                           }
                         },
                       ),
                     ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              SwitchListTile(
                title: Text('Allow Position Overlap', style: AppTextStyles.bodyLarge),
                subtitle: Text('New trades can open before previous ones close', style: AppTextStyles.bodyMedium),
                value: _allowThreadOverlap,
                onChanged: (val) {
                   setState(() => _allowThreadOverlap = val);
                   _saveUserRules(_userRules!.copyWith(allowThreadOverlap: val));
                },
                secondary: const Icon(Icons.layers_outlined, color: AppColors.secondary),
                activeColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceHighlight.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
            ],
          ),
        ),
      ],
     );
  }

  Widget _buildNumberInput({
    required double value,
    required String suffix,
    required Function(double) onChanged,
  }) {
    return TextFormField(
      key: ValueKey(value), 
      initialValue: value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
      ],
      textAlign: TextAlign.end,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        suffixText: suffix,
        suffixStyle: TextStyle(color: AppColors.textSecondary),
        fillColor: AppColors.surfaceHighlight.withOpacity(0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      onFieldSubmitted: (val) {
        final n = double.tryParse(val);
        if (n != null) onChanged(n);
      },
    );
  }
}
