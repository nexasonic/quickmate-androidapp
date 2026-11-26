import 'package:flutter/material.dart';
import '../core/app_dialogs.dart';
import '../core/app_language.dart';
import '../core/app_theme.dart';
import '../core/storage_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedTheme;
  late String _selectedLanguageCode;
  late bool _notifJobAlerts;
  late bool _notifMessages;
  late bool _notifPromotions;
  late bool _privacyShowLocation;

  final List<String> _themes = ['System', 'Light', 'Dark'];

  @override
  void initState() {
    super.initState();
    _loadLocalSettings();
    _syncFromServer();
  }

  void _loadLocalSettings() {
    _selectedTheme = StorageService.getThemeMode();
    _selectedLanguageCode = appLocaleNotifier.value.languageCode;
    _notifJobAlerts = StorageService.getNotifJobAlerts();
    _notifMessages = StorageService.getNotifMessages();
    _notifPromotions = StorageService.getNotifPromotions();
    _privacyShowLocation = StorageService.getPrivacyShowLocation();
  }

  Future<void> _syncFromServer() async {
    if (!AuthService.isLoggedIn()) return;
    await ProfileService.fetchUserProfile();
    if (!mounted) return;
    setState(() {
      _loadLocalSettings();
    });
  }

  String _getTranslatedTheme(String theme) {
    switch (theme) {
      case 'Light':
        return context.tr('light');
      case 'Dark':
        return context.tr('dark');
      case 'System':
      default:
        return context.tr('system');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryDark = AppTheme.primary(context);
    _selectedLanguageCode = appLocaleNotifier.value.languageCode;

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      appBar: AppBar(
        backgroundColor: AppTheme.appBarBg(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('settings'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _syncFromServer,
        color: primaryDark,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appearance & Theme
              _buildSectionHeader(context.tr('appearance_theme'), context),
              _buildCardGroup(context, [
                _buildDropdownSettingTile(
                  icon: Icons.palette_outlined,
                  title: context.tr('app_theme'),
                  subtitle: _getTranslatedTheme(_selectedTheme),
                  value: _selectedTheme,
                  items: _themes.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(_getTranslatedTheme(t), style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    if (val == null) return;
                    setState(() {
                      _selectedTheme = val;
                    });
                    final msgPrefix = context.tr('theme_set_to');
                    final translatedTheme = _getTranslatedTheme(val);
                    await updateAppTheme(val);
                    if (AuthService.isLoggedIn()) {
                      await ProfileService.updateProfile(prefTheme: themeModeToInt(val));
                    }
                    if (!context.mounted) return;
                    AppDialogs.showToastModal(
                      context,
                      message: '$msgPrefix $translatedTheme',
                    );
                  },
                  primaryDark: primaryDark,
                ),
                Divider(height: 1, indent: 56, color: AppTheme.divider(context)),
                _buildDropdownSettingTile(
                  icon: Icons.language_outlined,
                  title: context.tr('app_language'),
                  subtitle: AppLanguage.getLanguageName(_selectedLanguageCode),
                  value: _selectedLanguageCode,
                  items: AppLanguage.supportedLanguages.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, style: TextStyle(color: AppTheme.textPrimary(context), fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    if (val == null) return;
                    setState(() {
                      _selectedLanguageCode = val;
                    });
                    final msgPrefix = context.tr('language_set_to');
                    final langName = AppLanguage.getLanguageName(val);
                    await AppLanguage.setLanguage(val);
                    if (AuthService.isLoggedIn()) {
                      await ProfileService.updateProfile(prefLanguage: AppLanguage.languageCodeToInt(val));
                    }
                    if (!context.mounted) return;
                    AppDialogs.showToastModal(
                      context,
                      message: '$msgPrefix $langName',
                    );
                  },
                  primaryDark: primaryDark,
                ),
              ]),
              const SizedBox(height: 20),

              // Push Notifications
              _buildSectionHeader(context.tr('push_notifications'), context),
              _buildCardGroup(context, [
                SwitchListTile(
                  secondary: Icon(Icons.work_outline_rounded, color: primaryDark),
                  title: Text(context.tr('live_work_job_alerts'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                  subtitle: Text(context.tr('live_work_alerts_desc'), style: TextStyle(color: AppTheme.textSecondary(context))),
                  value: _notifJobAlerts,
                  activeTrackColor: primaryDark,
                  onChanged: (val) async {
                    setState(() {
                      _notifJobAlerts = val;
                    });
                    await StorageService.saveNotifJobAlerts(val);
                    if (AuthService.isLoggedIn()) {
                      await ProfileService.updateProfile(notifJobAlerts: val);
                    }
                  },
                ),
                Divider(height: 1, indent: 56, color: AppTheme.divider(context)),
                SwitchListTile(
                  secondary: Icon(Icons.chat_bubble_outline_rounded, color: primaryDark),
                  title: Text(context.tr('chat_message_notifs'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                  subtitle: Text(context.tr('chat_notifs_desc'), style: TextStyle(color: AppTheme.textSecondary(context))),
                  value: _notifMessages,
                  activeTrackColor: primaryDark,
                  onChanged: (val) async {
                    setState(() {
                      _notifMessages = val;
                    });
                    await StorageService.saveNotifMessages(val);
                    if (AuthService.isLoggedIn()) {
                      await ProfileService.updateProfile(notifMessages: val);
                    }
                  },
                ),
                Divider(height: 1, indent: 56, color: AppTheme.divider(context)),
                SwitchListTile(
                  secondary: Icon(Icons.campaign_outlined, color: primaryDark),
                  title: Text(context.tr('promotions_offers'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                  subtitle: Text(context.tr('promotions_desc'), style: TextStyle(color: AppTheme.textSecondary(context))),
                  value: _notifPromotions,
                  activeTrackColor: primaryDark,
                  onChanged: (val) async {
                    setState(() {
                      _notifPromotions = val;
                    });
                    await StorageService.saveNotifPromotions(val);
                    if (AuthService.isLoggedIn()) {
                      await ProfileService.updateProfile(notifPromotions: val);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 20),

              // Privacy & Location Settings
              _buildSectionHeader(context.tr('privacy_location'), context),
              _buildCardGroup(context, [
                SwitchListTile(
                  secondary: Icon(Icons.location_on_outlined, color: primaryDark),
                  title: Text(context.tr('show_location_nearby'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                  subtitle: Text(context.tr('show_location_desc'), style: TextStyle(color: AppTheme.textSecondary(context))),
                  value: _privacyShowLocation,
                  activeTrackColor: primaryDark,
                  onChanged: (val) async {
                    setState(() {
                      _privacyShowLocation = val;
                    });
                    await StorageService.savePrivacyShowLocation(val);
                    if (AuthService.isLoggedIn()) {
                      await ProfileService.updateProfile(showLocation: val);
                    }
                    if (!val && context.mounted) {
                      AppDialogs.showSuccessModal(
                        context,
                        title: context.tr('location_disabled_alert_title'),
                        message: context.tr('location_disabled_alert_desc'),
                        icon: Icons.location_off_rounded,
                        iconColor: const Color(0xFFF59E0B),
                      );
                    }
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required Color primaryDark,
  }) {
    final isDark = AppTheme.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? primaryDark.withValues(alpha: 0.2) : primaryDark.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryDark, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border(context)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: AppTheme.surface(context),
                isDense: true,
                icon: Icon(Icons.arrow_drop_down_rounded, color: AppTheme.textSecondary(context)),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary(context),
        ),
      ),
    );
  }

  Widget _buildCardGroup(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(children: children),
    );
  }
}
