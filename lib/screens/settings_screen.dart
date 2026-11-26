import 'package:flutter/material.dart';
import '../core/app_dialogs.dart';
import '../core/app_language.dart';
import '../core/app_theme.dart';
import '../core/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedTheme;
  late String _selectedLanguageCode;
  bool _notifJobAlerts = true;
  bool _notifMessages = true;
  bool _notifPromotions = false;
  bool _privacyShowLocation = true;

  final List<String> _themes = ['System', 'Light', 'Dark'];

  @override
  void initState() {
    super.initState();
    _selectedTheme = StorageService.getThemeMode();
    _selectedLanguageCode = appLocaleNotifier.value.languageCode;
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
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 400));
          if (mounted) setState(() {});
        },
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
                ListTile(
                  leading: Icon(Icons.palette_outlined, color: primaryDark),
                  title: Text(context.tr('app_theme'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                  subtitle: Text(_getTranslatedTheme(_selectedTheme), style: TextStyle(color: AppTheme.textSecondary(context))),
                  trailing: DropdownButton<String>(
                    value: _selectedTheme,
                    dropdownColor: AppTheme.surface(context),
                    underline: const SizedBox(),
                    items: _themes.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(_getTranslatedTheme(t), style: TextStyle(color: AppTheme.textPrimary(context))),
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
                      if (!context.mounted) return;
                      AppDialogs.showToastModal(
                        context,
                        message: '$msgPrefix $translatedTheme',
                      );
                    },
                  ),
                ),
                Divider(height: 1, indent: 56, color: AppTheme.divider(context)),
                ListTile(
                  leading: Icon(Icons.language_outlined, color: primaryDark),
                  title: Text(context.tr('app_language'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                  subtitle: Text(
                    AppLanguage.getLanguageName(_selectedLanguageCode),
                    style: TextStyle(color: AppTheme.textSecondary(context)),
                  ),
                  trailing: DropdownButton<String>(
                    value: _selectedLanguageCode,
                    dropdownColor: AppTheme.surface(context),
                    underline: const SizedBox(),
                    items: AppLanguage.supportedLanguages.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value, style: TextStyle(color: AppTheme.textPrimary(context))),
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
                      if (!context.mounted) return;
                      AppDialogs.showToastModal(
                        context,
                        message: '$msgPrefix $langName',
                      );
                    },
                  ),
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
                  onChanged: (val) {
                    setState(() {
                      _notifJobAlerts = val;
                    });
                  },
                ),
                Divider(height: 1, indent: 56, color: AppTheme.divider(context)),
                SwitchListTile(
                  secondary: Icon(Icons.chat_bubble_outline_rounded, color: primaryDark),
                  title: Text(context.tr('chat_message_notifs'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                  subtitle: Text(context.tr('chat_notifs_desc'), style: TextStyle(color: AppTheme.textSecondary(context))),
                  value: _notifMessages,
                  activeTrackColor: primaryDark,
                  onChanged: (val) {
                    setState(() {
                      _notifMessages = val;
                    });
                  },
                ),
                Divider(height: 1, indent: 56, color: AppTheme.divider(context)),
                SwitchListTile(
                  secondary: Icon(Icons.campaign_outlined, color: primaryDark),
                  title: Text(context.tr('promotions_offers'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                  subtitle: Text(context.tr('promotions_desc'), style: TextStyle(color: AppTheme.textSecondary(context))),
                  value: _notifPromotions,
                  activeTrackColor: primaryDark,
                  onChanged: (val) {
                    setState(() {
                      _notifPromotions = val;
                    });
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
                  onChanged: (val) {
                    setState(() {
                      _privacyShowLocation = val;
                    });
                  },
                ),
              ]),
            ],
          ),
        ),
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
