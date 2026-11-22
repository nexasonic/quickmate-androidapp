import 'package:flutter/material.dart';
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
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _user = AuthService.getStoredUser();
    final profile = await ProfileService.fetchUserProfile();
    if (!mounted) return;
    setState(() {
      _user = profile ?? _user;
    });
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
                builder: (loadingContext) => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF094943)),
                ),
              );

              await AuthService.logout();

              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true).pop();

              setState(() {
                _user = null;
              });

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF094943);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: Stack(
        children: [
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF064E3B),
                  Color(0xFF094943),
                  Color(0xFF0D9488),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage your account and preferences.',
                    style: TextStyle(
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

                  _buildMenuGroup([
                    _buildMenuItem(
                      icon: Icons.person_outline_rounded,
                      iconBg: const Color(0xFFDCFCE7),
                      iconColor: const Color(0xFF16A34A),
                      title: 'My Profile',
                      subtitle: 'View and update your personal details',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyProfileScreen()),
                        );
                        _loadProfile();
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.business_center_outlined,
                      iconBg: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      title: 'My Live Work Cards',
                      subtitle: 'Manage your active live work cards',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyCardsScreen()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.bookmark_border_rounded,
                      iconBg: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Saved Cards',
                      subtitle: 'Quick access to bookmarked live work cards',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SavedCardsScreen()),
                        );
                      },
                      showDivider: false,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  _buildMenuGroup([
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      iconBg: const Color(0xFFE6F4F1),
                      iconColor: primaryDark,
                      title: 'Settings',
                      subtitle: 'App, privacy and account settings',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsScreen()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.help_outline_rounded,
                      iconBg: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      title: 'Help & Support',
                      subtitle: 'Get help, FAQs and contact support',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.info_outline_rounded,
                      iconBg: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF7C3AED),
                      title: 'About Us',
                      subtitle: 'App version v1.0.0, terms and privacy',
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
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context) {
    const primaryDark = Color(0xFF094943);
    final userName = _user?.name ?? 'User Profile';
    final userEmail = _user?.email ?? (_user?.phone ?? 'QuickMate User');
    final avatarUrl = _user?.avatarUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userEmail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _user?.isVerified == true ? 'VERIFIED USER' : 'ACTIVE USER',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardsRow(BuildContext context) {
    return Row(
      children: [
        _buildStatCard('Live Works', 'Active', onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyCardsScreen()),
          );
        }),
        const SizedBox(width: 10),
        _buildStatCard('Saved Cards', 'View All', onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SavedCardsScreen()),
          );
        }),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF094943),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
      ),
      child: Column(children: items),
    );
  }

  Widget _buildMenuItem({
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
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 68, endIndent: 16, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    final bool loggedIn = AuthService.isLoggedIn();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: loggedIn ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7)),
      ),
      child: ListTile(
        onTap: () {
          if (loggedIn) {
            _showLogoutDialog(context);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          }
        },
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: loggedIn ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            loggedIn ? Icons.logout_rounded : Icons.login_rounded,
            color: loggedIn ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
            size: 20,
          ),
        ),
        title: Text(
          loggedIn ? 'Log Out' : 'Sign In / Register',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: loggedIn ? const Color(0xFFEF4444) : const Color(0xFF16A34A),
          ),
        ),
        subtitle: Text(
          loggedIn
              ? 'Sign out of your account on this device'
              : 'Sign in or create an account to post cards & chat',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
