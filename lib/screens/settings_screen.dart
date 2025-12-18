import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart'; // Import AuthService
import '../services/config_service.dart';
import '../theme/app_theme.dart';
import 'admin_seasonals_dashboard.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ApiService _apiService;
  late AuthService _authService; // Add AuthService
  bool _isLoading = true;
  String? _error;
  User? _settings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(baseUrl: ConfigService().apiBaseUrl);
    _authService = AuthService(); // Initialize AuthService
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      setState(() => _isLoading = true);
      final settings = await _apiService.getUser();
      if (mounted) {
        setState(() {
          _settings = settings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load settings: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings(User updated) async {
    setState(() => _isSaving = true);
    try {
      final savedSettings = await _apiService.saveUser(updated);
      setState(() {
        _settings = savedSettings;
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  Future<void> _retryVerification(String accountId) async {
    setState(() => _isSaving = true);
    try {
      final verified = await _apiService.verifyAlpacaAccount(accountId);
      
      if (mounted) {
        if (verified) {
          // Update local state
          final accounts = List<AlpacaAccount>.from(_settings!.alpacaAccounts);
          final index = accounts.indexWhere((a) => a.id == accountId);
          if (index != -1) {
             final acc = accounts[index];
             accounts[index] = AlpacaAccount(
                 id: acc.id, 
                 label: acc.label, 
                 apiKey: acc.apiKey, 
                 apiSecret: acc.apiSecret, 
                 isPaper: acc.isPaper, 
                 verified: true
             );
             setState(() {
               _settings = _settings!.copyWith(alpacaAccounts: accounts);
             });
          }
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account verified successfully')));
        } else {
          // If failed, we might want to ensure it's marked as false locally too
           final accounts = List<AlpacaAccount>.from(_settings!.alpacaAccounts);
           final index = accounts.indexWhere((a) => a.id == accountId);
           if (index != -1) {
             final acc = accounts[index];
             if (acc.verified) {
                accounts[index] = AlpacaAccount(
                   id: acc.id, 
                   label: acc.label, 
                   apiKey: acc.apiKey, 
                   apiSecret: acc.apiSecret, 
                   isPaper: acc.isPaper, 
                   verified: false
                );
                setState(() {
                  _settings = _settings!.copyWith(alpacaAccounts: accounts);
                });
             }
           }
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification failed. Check credentials.')));
        }
      }
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
       }
    } finally {
        if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addAccount() {
    if (_settings == null) return;
    
    final newAccount = AlpacaAccount(
      id: const Uuid().v4(),
      label: 'New Account',
      apiKey: '',
      apiSecret: '',
      isPaper: true,
      verified: false,
    );

    final updated = _settings!.copyWith(
      alpacaAccounts: [..._settings!.alpacaAccounts, newAccount],
    );
    
    _saveSettings(updated);
  }

  void _updateAccount(int index, AlpacaAccount account) {
    if (_settings == null) return;
    
    final accounts = List<AlpacaAccount>.from(_settings!.alpacaAccounts);
    accounts[index] = account;
    
    final updated = _settings!.copyWith(alpacaAccounts: accounts);
    _saveSettings(updated);
  }

  void _deleteAccount(int index) {
    if (_settings == null) return;
    
    final accounts = List<AlpacaAccount>.from(_settings!.alpacaAccounts);
    accounts.removeAt(index);
    
    // Check if we need to disable trading flags if no keys left
    bool livePossible = accounts.any((a) => !a.isPaper && a.apiKey.isNotEmpty);
    bool paperPossible = accounts.any((a) => a.isPaper && a.apiKey.isNotEmpty);
    
    final updated = _settings!.copyWith(
      alpacaAccounts: accounts,
      enableLiveTrading: _settings!.enableLiveTrading && livePossible,
      enablePaperTrading: _settings!.enablePaperTrading && paperPossible,
    );
    
    _saveSettings(updated);
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut(); // Use AuthService to sign out
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.headlineLarge),
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
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null 
          ? Center(child: Text(_error!, style: AppTextStyles.bodyLarge))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAdminSection(),
                _buildEnvironmentSection(),
                const SizedBox(height: 24),
                _buildStrategyLinkingSection('Seasonal Strategy', 
                    _settings!.linkAccountSeasonal, 
                    (updated) => _saveSettings(_settings!.copyWith(linkAccountSeasonal: updated))),
                const SizedBox(height: 24),
                _buildStrategyLinkingSection('Day Trading Strategy', 
                    _settings!.linkAccountDaytrade, 
                    (updated) => _saveSettings(_settings!.copyWith(linkAccountDaytrade: updated))),
                const SizedBox(height: 24),
                _buildAccountsSection(),
                
                const SizedBox(height: 40),
                Divider(color: Colors.white.withOpacity(0.05)),
                const SizedBox(height: 24),
                
                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: AppColors.error),
                    label: Text('Sign Out', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                // Add bottom padding for floating nav
                const SizedBox(height: 120),
              ],
            ),
    );
  }

  Widget _buildAdminSection() {
    if (_settings?.isAdmin != true) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ListTile(
            leading: Icon(Icons.admin_panel_settings, color: AppColors.primary),
            title: Text('Admin Seasonals Dashboard', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
            subtitle: Text('Manage seasonal trades', style: AppTextStyles.bodyMedium),
            trailing: Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSeasonalsDashboard())),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStrategyLinkingSection(
      String title, 
      LinkedAccountIds? currentLinks,
      Function(LinkedAccountIds) onUpdate
  ) {
    if (_settings == null) return const SizedBox.shrink();

    final paperAccounts = _settings!.alpacaAccounts.where((a) => a.isPaper).toList();
    final liveAccounts = _settings!.alpacaAccounts.where((a) => !a.isPaper).toList();

    String? selectedPaperId = currentLinks?.paperAccountId;
    String? selectedLiveId = currentLinks?.liveAccountId;

    // Validate if selected ID still exists
    if (selectedPaperId != null && !paperAccounts.any((a) => a.id == selectedPaperId)) selectedPaperId = null;
    if (selectedLiveId != null && !liveAccounts.any((a) => a.id == selectedLiveId)) selectedLiveId = null;

    final missingLink = selectedPaperId == null && selectedLiveId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: AppTextStyles.headlineLarge.copyWith(fontSize: 18, color: AppColors.primary)),
            if (missingLink) ...[
               const SizedBox(width: 8),
               const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
               Text(' Not Configured', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.warning, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
               DropdownButtonFormField<String>(
                 decoration: InputDecoration(
                   labelText: 'Paper Trading Account', 
                   labelStyle: AppTextStyles.bodyMedium,
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                   filled: true,
                   fillColor: AppColors.surfaceHighlight.withOpacity(0.3),
                 ),
                 value: selectedPaperId,
                 dropdownColor: AppColors.surface,
                 style: AppTextStyles.bodyLarge,
                 items: [
                   const DropdownMenuItem(value: null, child: Text('None')),
                   ...paperAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.label))),
                 ],
                 onChanged: (val) {
                    final updatedLink = LinkedAccountIds(
                      paperAccountId: val,
                      liveAccountId: selectedLiveId // Keep existing live selection
                    );
                    onUpdate(updatedLink);
                 },
               ),
               const SizedBox(height: 16),
               DropdownButtonFormField<String>(
                 decoration: InputDecoration(
                   labelText: 'Live Trading Account', 
                   labelStyle: AppTextStyles.bodyMedium,
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                   filled: true,
                   fillColor: AppColors.surfaceHighlight.withOpacity(0.3),
                 ),
                 value: selectedLiveId,
                 dropdownColor: AppColors.surface,
                 style: AppTextStyles.bodyLarge,
                 items: [
                   const DropdownMenuItem(value: null, child: Text('None')),
                   ...liveAccounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.label))),
                 ],
                 onChanged: (val) {
                    final updatedLink = LinkedAccountIds(
                      paperAccountId: selectedPaperId, // Keep existing paper selection
                      liveAccountId: val
                    );
                    onUpdate(updatedLink);
                 },
               ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnvironmentSection() {
    if (_settings == null) return const SizedBox.shrink();

    // Check availability
    final hasLiveKeys = _settings!.alpacaAccounts.any((a) => !a.isPaper && a.apiKey.isNotEmpty);
    final hasPaperKeys = _settings!.alpacaAccounts.any((a) => a.isPaper && a.apiKey.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trading Environment', style: AppTextStyles.headlineLarge.copyWith(fontSize: 18, color: AppColors.primary)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: Text('Enable Paper Trading', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                subtitle: hasPaperKeys 
                  ? Text('Execute trades in simulated environment', style: AppTextStyles.bodyMedium) 
                  : Text('Add Paper API keys to enable', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.warning)),
                value: _settings!.enablePaperTrading,
                activeColor: AppColors.accent,
                inactiveTrackColor: AppColors.surfaceHighlight.withOpacity(0.5),
                onChanged: hasPaperKeys 
                  ? (val) => _saveSettings(_settings!.copyWith(enablePaperTrading: val))
                  : null,
                secondary: const Icon(Icons.assignment_outlined, color: AppColors.accent),
              ),
              Divider(height: 1, color: Colors.white.withOpacity(0.05)),
              SwitchListTile(
                title: Text('Enable Live Trading', style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                subtitle: hasLiveKeys 
                  ? Text('Execute trades with real capital', style: AppTextStyles.bodyMedium) 
                  : Text('Add Live API keys to enable', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.warning)),
                value: _settings!.enableLiveTrading,
                activeColor: AppColors.error,
                inactiveTrackColor: AppColors.surfaceHighlight.withOpacity(0.5),
                onChanged: hasLiveKeys 
                  ? (val) => _saveSettings(_settings!.copyWith(enableLiveTrading: val))
                  : null,
                secondary: const Icon(Icons.bolt, color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsSection() {
    if (_settings == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Alpaca Accounts', style: AppTextStyles.headlineLarge.copyWith(fontSize: 18, color: AppColors.primary)),
            TextButton.icon(
              onPressed: _addAccount,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Account'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            )
          ],
        ),
        const SizedBox(height: 8),
        if (_settings!.alpacaAccounts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Center(child: Text('No accounts configured', style: AppTextStyles.bodyMedium)),
          )
        else
          ..._settings!.alpacaAccounts.asMap().entries.map((entry) {
            final index = entry.key;
            final account = entry.value;
            return _AccountCard(
              account: account, 
              onUpdate: (updated) => _updateAccount(index, updated),
              onDelete: () => _deleteAccount(index),
              onRetryVerification: () => _retryVerification(account.id),
            );
          }),
      ],
    );
  }
}

class _AccountCard extends StatefulWidget {
  final AlpacaAccount account;
  final Function(AlpacaAccount) onUpdate;
  final VoidCallback onDelete;
  final VoidCallback onRetryVerification;

  const _AccountCard({
    required this.account, 
    required this.onUpdate, 
    required this.onDelete,
    required this.onRetryVerification,
  });

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _expanded = false;
  late TextEditingController _labelCtrl;
  late TextEditingController _keyCtrl;
  late TextEditingController _secretCtrl;
  late bool _isPaper;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.account.label);
    _keyCtrl = TextEditingController(text: widget.account.apiKey);
    _secretCtrl = TextEditingController(text: widget.account.apiSecret);
    _isPaper = widget.account.isPaper;
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _keyCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = AlpacaAccount(
      id: widget.account.id,
      label: _labelCtrl.text,
      apiKey: _keyCtrl.text,
      apiSecret: _secretCtrl.text,
      isPaper: _isPaper,
      verified: widget.account.verified,
    );
    widget.onUpdate(updated);
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = widget.account.apiKey.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.account.label, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                _buildBadge(widget.account.isPaper ? 'PAPER' : 'LIVE', widget.account.isPaper ? AppColors.accent : AppColors.error),
                const SizedBox(width: 8),
                if (hasKey) ...[
                   _buildBadge(widget.account.verified ? 'VERIFIED' : 'UNVERIFIED', widget.account.verified ? AppColors.success : AppColors.warning),
                   if (!widget.account.verified) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 24,
                        child: OutlinedButton(
                          onPressed: widget.onRetryVerification, 
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            side: BorderSide(color: AppColors.warning.withOpacity(0.5)),
                            foregroundColor: AppColors.warning,
                          ),
                          child: const Text('Retry', style: TextStyle(fontSize: 10))
                        ),
                      )
                   ]
                ] else 
                   _buildBadge('NO KEYS', AppColors.textDisabled),
              ],
            ),
            trailing: IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.edit),
              color: AppColors.textSecondary,
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _labelCtrl,
                    style: AppTextStyles.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Account Label',
                      labelStyle: AppTextStyles.bodyMedium,
                      filled: true,
                      fillColor: AppColors.surfaceHighlight.withOpacity(0.3),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Environment Toggle
                  Row(
                    children: [
                        Text('Environment:', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        ChoiceChip(
                            label: const Text('Paper'),
                            selected: _isPaper,
                            onSelected: (val) => setState(() => _isPaper = true),
                            selectedColor: AppColors.accent.withOpacity(0.2),
                            labelStyle: TextStyle(color: _isPaper ? AppColors.accent : AppColors.textSecondary),
                            backgroundColor: AppColors.surfaceHighlight.withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                            label: const Text('Live'),
                            selected: !_isPaper,
                            onSelected: (val) => setState(() => _isPaper = false),
                            selectedColor: AppColors.error.withOpacity(0.2),
                            labelStyle: TextStyle(color: !_isPaper ? AppColors.error : AppColors.textSecondary),
                            backgroundColor: AppColors.surfaceHighlight.withOpacity(0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  Text('API Keys', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _keyCtrl,
                    style: AppTextStyles.monoMedium,
                    decoration: InputDecoration(
                      labelText: 'API Key ID', 
                      isDense: true, 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.surfaceHighlight.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _secretCtrl,
                    style: AppTextStyles.monoMedium,
                    decoration: InputDecoration(
                      labelText: 'Secret Key', 
                      isDense: true, 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.surfaceHighlight.withOpacity(0.3),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, color: AppColors.error),
                        label: Text('Delete', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                      ),
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save Changes'),
                      ),
                    ],
                  )
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Text(
        text, 
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)
      ),
    );
  }
}
