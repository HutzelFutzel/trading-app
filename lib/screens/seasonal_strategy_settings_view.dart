import 'dart:async';
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
  Timer? _debounce;

  // Data
  SeasonalStrategyUserSettings? _userRules;
  List<int> _availableThreads = [];

  // Local State for Edit
  late String _allocationMode;
  late Map<int, double> _customAllocationsPaper;
  late Map<int, double> _customAllocationsLive;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
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
    _allocationMode = _userRules!.allocationMode;
    _customAllocationsPaper = Map.from(_userRules!.customAllocationsPaper);
    _customAllocationsLive = Map.from(_userRules!.customAllocationsLive);

    // Defaults for allocation if missing
    final share = 100.0 / _availableThreads.length;
    
    if (_customAllocationsPaper.isEmpty) {
      for (var t in _availableThreads) {
        _customAllocationsPaper[t] = share;
      }
    }
    if (_customAllocationsLive.isEmpty) {
      for (var t in _availableThreads) {
        _customAllocationsLive[t] = share;
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
  
  void _debouncedSave(SeasonalStrategyUserSettings newRules) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 1), () {
      _saveUserRules(newRules);
    });
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
            _buildThreadsSection(),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildThreadsSection() {
    // Filter active threads
    final activeThreads = _availableThreads.where((t) => _getTradeIdsForThread(t).isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'THREAD CONFIGURATION',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        
        // Beautiful Allocation Toggle
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(child: _buildModeButton('Equal', _allocationMode == 'equal', () {
                setState(() => _allocationMode = 'equal');
                // In Equal mode, allocations are calculated dynamically per environment (Paper/Live)
                _saveUserRules(_userRules!.copyWith(allocationMode: 'equal'));
              })),
              const SizedBox(width: 4),
              Expanded(child: _buildModeButton('Custom', _allocationMode == 'custom', () {
                 setState(() => _allocationMode = 'custom');
                 _saveUserRules(_userRules!.copyWith(allocationMode: 'custom'));
              })),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Hint Text
        Container(
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(
             color: AppColors.primary.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: AppColors.primary.withOpacity(0.2)),
           ),
           child: Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
               const SizedBox(width: 8),
               Expanded(
                 child: Text(
                   _allocationMode == 'equal' 
                     ? 'Equal: Allocations are calculated dynamically based on active threads in each environment (Paper/Live) separately.'
                     : 'Custom: If one thread should have a higher portfolio weight than others.',
                   style: AppTextStyles.bodyMedium.copyWith(fontSize: 12, color: AppColors.textSecondary),
                 ),
               ),
             ],
           ),
        ),
        const SizedBox(height: 24),
        
        if (activeThreads.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No active threads found.\nAssign trades to threads to configure them.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeThreads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final threadId = activeThreads[index];
              return _buildThreadCard(threadId);
            },
          ),
      ],
    );
  }

  Widget _buildModeButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildThreadCard(int threadId) {
    final threadColor = AppTheme.threadColors[threadId] ?? Colors.grey;
    final allocationPaper = _customAllocationsPaper[threadId] ?? 0;
    final allocationLive = _customAllocationsLive[threadId] ?? 0;
    
    final tradeIds = _getTradeIdsForThread(threadId);
    
    // Count paper and live
    final paperCount = tradeIds.where((id) => _userRules!.paperTradeIds.contains(id)).length;
    final liveCount = tradeIds.where((id) => _userRules!.liveTradeIds.contains(id)).length;

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
                const SizedBox(height: 4),
                Row(
                  children: [
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(
                         color: AppColors.accent.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text('$paperCount Paper', style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                     ),
                     const SizedBox(width: 8),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                       decoration: BoxDecoration(
                         color: AppColors.error.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text('$liveCount Live', style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                     ),
                  ],
                ),
              ],
            ),
          ),

          // Controls - Allocation
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_allocationMode == 'equal') ...[
                  if (paperCount > 0)
                     Text('P: ${_userRules!.getEqualAllocation(isPaper: true).toStringAsFixed(1)}%', 
                       style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent, fontSize: 10)),
                  if (liveCount > 0)
                     Text('L: ${_userRules!.getEqualAllocation(isPaper: false).toStringAsFixed(1)}%', 
                       style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 10)),
                  if (paperCount == 0 && liveCount == 0)
                     const Text('0.0%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ]
                else ...[
                  // Custom Paper
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('P: ', style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                      SizedBox(
                        width: 70,
                        child: _buildNumberInput(
                          value: allocationPaper,
                          suffix: '%',
                          onChanged: (val) {
                             double sum = 0;
                             _customAllocationsPaper.forEach((k, v) { if(k != threadId) sum += v; });
                             if (sum + val <= 100.1) {
                                final newAlloc = Map<int, double>.from(_customAllocationsPaper);
                                newAlloc[threadId] = val;
                                setState(() => _customAllocationsPaper = newAlloc);
                                _debouncedSave(_userRules!.copyWith(customAllocationsPaper: newAlloc));
                             }
                          }
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Custom Live
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text('L: ', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                      SizedBox(
                         width: 70,
                         child: _buildNumberInput(
                          value: allocationLive,
                          suffix: '%',
                          onChanged: (val) {
                             double sum = 0;
                             _customAllocationsLive.forEach((k, v) { if(k != threadId) sum += v; });
                             if (sum + val <= 100.1) {
                                final newAlloc = Map<int, double>.from(_customAllocationsLive);
                                newAlloc[threadId] = val;
                                setState(() => _customAllocationsLive = newAlloc);
                                _debouncedSave(_userRules!.copyWith(customAllocationsLive: newAlloc));
                             }
                          }
                        ),
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
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
      onChanged: (val) {
        final n = double.tryParse(val);
        if (n != null) onChanged(n);
      },
    );
  }
}
