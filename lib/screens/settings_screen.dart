import 'package:flutter/material.dart';
import '../core/app_dialogs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedTheme = 'System';
  String _selectedLanguage = 'English';
  bool _notifJobAlerts = true;
  bool _notifMessages = true;
  bool _notifPromotions = false;
  bool _privacyShowLocation = true;

  final List<String> _themes = ['System', 'Light', 'Dark'];
  final List<String> _languages = ['English', 'Hindi', 'Malayalam', 'Spanish', 'French'];

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF094943);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Appearance & Theme
            _buildSectionHeader('Appearance & Theme'),
            _buildCardGroup([
              ListTile(
                leading: const Icon(Icons.palette_outlined, color: primaryDark),
                title: const Text('App Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_selectedTheme),
                trailing: DropdownButton<String>(
                  value: _selectedTheme,
                  underline: const SizedBox(),
                  items: _themes.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t));
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedTheme = val;
                    });
                    AppDialogs.showToastModal(
                      context,
                      message: 'Theme set to $val',
                    );
                  },
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.language_outlined, color: primaryDark),
                title: const Text('App Language', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_selectedLanguage),
                trailing: DropdownButton<String>(
                  value: _selectedLanguage,
                  underline: const SizedBox(),
                  items: _languages.map((l) {
                    return DropdownMenuItem(value: l, child: Text(l));
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _selectedLanguage = val;
                    });
                    AppDialogs.showToastModal(
                      context,
                      message: 'Language set to $val',
                    );
                  },
                ),
              ),
            ]),
            const SizedBox(height: 20),

            // Push Notifications
            _buildSectionHeader('Push Notifications'),
            _buildCardGroup([
              SwitchListTile(
                secondary: const Icon(Icons.work_outline_rounded, color: primaryDark),
                title: const Text('Live Work & Job Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Receive alerts for nearby live work cards'),
                value: _notifJobAlerts,
                activeTrackColor: primaryDark,
                onChanged: (val) {
                  setState(() {
                    _notifJobAlerts = val;
                  });
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: const Icon(Icons.chat_bubble_outline_rounded, color: primaryDark),
                title: const Text('Chat & Message Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Get notified when users send you a message'),
                value: _notifMessages,
                activeTrackColor: primaryDark,
                onChanged: (val) {
                  setState(() {
                    _notifMessages = val;
                  });
                },
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                secondary: const Icon(Icons.campaign_outlined, color: primaryDark),
                title: const Text('Promotions & Offers', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Receive updates on features & news'),
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
            _buildSectionHeader('Privacy & Location'),
            _buildCardGroup([
              SwitchListTile(
                secondary: const Icon(Icons.location_on_outlined, color: primaryDark),
                title: const Text('Show Location to Nearby Users', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Allow nearby users to see your distance'),
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }
}
