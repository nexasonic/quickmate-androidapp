import 'package:flutter/material.dart';
import 'core/api_config.dart';
import 'core/app_dialogs.dart';
import 'core/app_language.dart';
import 'core/app_theme.dart';
import 'login_screen.dart';
import 'my_cards_screen.dart';
import 'models/user_model.dart';
import 'screens/about_us_screen.dart';
import 'screens/help_support_screen.dart';
import 'screens/my_profile_screen.dart';
import 'screens/saved_cards_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';
import 'services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;
  int _imageTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> refresh() => _loadProfile();

  Future<void> _loadProfile() async {
    _user = AuthService.getStoredUser();
    final profile = await ProfileService.fetchUserProfile();
    if (!mounted) return;
    setState(() {
      _user = profile ?? _user;
      _imageTimestamp = DateTime.now().millisecondsSinceEpoch;
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface(dialogContext),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.border(dialogContext)),
        ),
        title: Text(context.tr('logout'), style: TextStyle(color: AppTheme.textPrimary(dialogContext))),
        content: Text(
          context.tr('logout_confirm'),
          style: TextStyle(color: AppTheme.textSecondary(dialogContext)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('cancel'), style: TextStyle(color: AppTheme.textSecondary(dialogContext))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => Center(
                  child: CircularProgressIndicator(color: AppTheme.primary(context)),
                ),
              );

              await AuthService.logout();

              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pop();

              setState(() {
                _user = null;
              });

              AppDialogs.showToastModal(
                context,
                message: context.tr('logged_out_success'),
              );
            },
            child: Text(dialogContext.tr('logout'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryDark = AppTheme.primary(context);
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.background(context),
      body: Stack(
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF042F2E),
                        const Color(0xFF0F172A),
                        const Color(0xFF0F172A),
                      ]
                    : [
                        const Color(0xFF064E3B),
                        const Color(0xFF094943),
                        const Color(0xFF0D9488),
                      ],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
          ),

          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadProfile,
              color: primaryDark,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('profile'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('manage_live_works_desc'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildUserInfoCard(context),
                    const SizedBox(height: 20),

                    _buildStatCardsRow(context),
                    const SizedBox(height: 20),

                    _buildMenuGroup(context, [
                      _buildMenuItem(
                        context: context,
                        icon: Icons.person_outline_rounded,
                        iconBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                        iconColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                        title: context.tr('my_profile'),
                        subtitle: context.tr('view_update_personal_details'),
                        onTap: () async {
                          if (!AuthService.isLoggedIn()) {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                            if (result == true) _loadProfile();
                            return;
                          }
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MyProfileScreen()),
                          );
                          _loadProfile();
                        },
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.business_center_outlined,
                        iconBg: isDark ? const Color(0xFF075985) : const Color(0xFFE0F2FE),
                        iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        title: context.tr('my_cards'),
                        subtitle: context.tr('manage_live_works_desc'),
                        onTap: () async {
                          if (!AuthService.isLoggedIn()) {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                            if (result == true) _loadProfile();
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MyCardsScreen()),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.bookmark_border_rounded,
                        iconBg: isDark ? const Color(0xFF581C87) : const Color(0xFFF3E8FF),
                        iconColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED),
                        title: context.tr('saved_cards'),
                        subtitle: context.tr('quick_access_saved_cards'),
                        onTap: () async {
                          if (!AuthService.isLoggedIn()) {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                            );
                            if (result == true) _loadProfile();
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SavedCardsScreen()),
                          );
                        },
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 16),

                    _buildMenuGroup(context, [
                      _buildMenuItem(
                        context: context,
                        icon: Icons.settings_outlined,
                        iconBg: isDark ? const Color(0xFF134E4A) : const Color(0xFFE6F4F1),
                        iconColor: primaryDark,
                        title: context.tr('settings'),
                        subtitle: context.tr('app_privacy_account_settings'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.help_outline_rounded,
                        iconBg: isDark ? const Color(0xFF075985) : const Color(0xFFE0F2FE),
                        iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        title: context.tr('help_support'),
                        subtitle: context.tr('get_help_faqs_contact'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
                          );
                        },
                      ),
                      _buildMenuItem(
                        context: context,
                        icon: Icons.info_outline_rounded,
                        iconBg: isDark ? const Color(0xFF581C87) : const Color(0xFFF3E8FF),
                        iconColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED),
                        title: context.tr('about_us'),
                        subtitle: context.tr('app_version_terms_privacy'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AboutUsScreen()),
                          );
                        },
                        showDivider: false,
                      ),
                    ]),
                    const SizedBox(height: 20),

                    _buildLogoutCard(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    final primaryDark = AppTheme.primary(context);
    final bool loggedIn = AuthService.isLoggedIn();

    final userName = loggedIn ? (_user?.name ?? context.tr('user_profile')) : context.tr('login');
    final userEmail = loggedIn ? (_user?.email ?? (_user?.phone ?? context.tr('quickmate_user'))) : context.tr('login_manage_account');
    String? avatarUrl = _user?.avatarUrl;
    if (loggedIn && avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarUrl = "${ApiConfig.fixImageUrl(avatarUrl)}?t=$_imageTimestamp";
    } else {
      avatarUrl = null;
    }

    return InkWell(
      onTap: () async {
        if (!loggedIn) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
          if (result == true) {
            _loadProfile();
          }
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyProfileScreen()),
          );
          _loadProfile();
        }
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: primaryDark,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Icon(loggedIn ? Icons.person : Icons.login_rounded, color: Colors.white, size: 28)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userEmail,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: loggedIn
                          ? (AppTheme.isDark(context) ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                          : (AppTheme.isDark(context) ? const Color(0xFF075985) : const Color(0xFFE0F2FE)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      loggedIn
                          ? (_user?.isVerified == true ? context.tr('verified_user') : context.tr('active_user'))
                          : context.tr('tap_to_log_in'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: loggedIn
                            ? (AppTheme.isDark(context) ? const Color(0xFF4ADE80) : const Color(0xFF166534))
                            : (AppTheme.isDark(context) ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCardsRow(BuildContext context) {
    return Row(
      children: [
        _buildStatCard(context, context.tr('live_work'), context.tr('active'), onTap: () async {
          if (!AuthService.isLoggedIn()) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
            if (result == true) _loadProfile();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyCardsScreen()),
          );
        }),
        const SizedBox(width: 10),
        _buildStatCard(context, context.tr('saved_cards'), context.tr('view_all'), onTap: () async {
          if (!AuthService.isLoggedIn()) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
            if (result == true) _loadProfile();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SavedCardsScreen()),
          );
        }),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.15 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: AppTheme.border(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.textSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGroup(BuildContext context, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.15 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary(context),
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary(context)),
        ),
        if (showDivider)
          Divider(height: 1, indent: 68, endIndent: 16, color: AppTheme.divider(context)),
      ],
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    final bool loggedIn = AuthService.isLoggedIn();
    final isDark = AppTheme.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: loggedIn
              ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFEE2E2))
              : (isDark ? const Color(0xFF065F46) : const Color(0xFFDCFCE7)),
        ),
      ),
      child: ListTile(
        onTap: () async {
          if (loggedIn) {
            _showLogoutDialog(context);
          } else {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
            if (result == true) {
              _loadProfile();
            }
          }
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: loggedIn
                ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
                : (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            loggedIn ? Icons.logout_rounded : Icons.login_rounded,
            color: loggedIn
                ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
                : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
            size: 20,
          ),
        ),
        title: Text(
          loggedIn ? context.tr('logout') : context.tr('sign_in_register'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: loggedIn
                ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
                : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
          ),
        ),
        subtitle: Text(
          loggedIn
              ? context.tr('sign_out_device_desc')
              : context.tr('sign_in_post_cards_desc'),
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
