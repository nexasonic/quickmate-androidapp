import 'package:flutter/material.dart';
import '../core/app_language.dart';
import '../core/app_theme.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryDark = AppTheme.primary(context);

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
          context.tr('about_us'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 400));
        },
        color: primaryDark,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // App Logo & Title
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.hexagon_outlined, size: 50, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'QuickMate',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.isDark(context) ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${context.tr('version')} v1.0.0',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Mission Statement Card
              Container(
                padding: const EdgeInsets.all(18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('our_mission'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('mission_desc'),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary(context),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Terms & Privacy Links Card
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border(context)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.description_outlined, color: primaryDark),
                      title: Text(context.tr('terms_of_service'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                      trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary(context)),
                      onTap: () {
                        _showPolicyDialog(
                          context,
                          context.tr('terms_of_service'),
                          context.tr('terms_of_service_desc'),
                        );
                      },
                    ),
                    Divider(height: 1, indent: 56, color: AppTheme.divider(context)),
                    ListTile(
                      leading: Icon(Icons.privacy_tip_outlined, color: primaryDark),
                      title: Text(context.tr('privacy_policy'), style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
                      trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary(context)),
                      onTap: () {
                        _showPolicyDialog(
                          context,
                          context.tr('privacy_policy'),
                          context.tr('privacy_policy_desc'),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                context.tr('all_rights_reserved'),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPolicyDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.border(context)),
        ),
        title: Text(title, style: TextStyle(color: AppTheme.textPrimary(context))),
        content: Text(
          content,
          style: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('close'), style: TextStyle(color: AppTheme.primary(context))),
          ),
        ],
      ),
    );
  }
}
