import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/providers/navigation_provider.dart';
import '../theme/app_colors.dart';
import 'custom_page_route.dart';

class AppDrawer extends ConsumerStatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const AppDrawer({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  bool _isProfileExpanded = false;

  void _handleLogout(BuildContext context) async {
    // Close drawer first
    Navigator.of(context).pop();
    
    // Perform logout
    await ref.read(authProvider.notifier).logout();
    
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        CustomPageRoute(
          child: LoginScreen(
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentIndex = ref.watch(navigationProvider);
    final isDark = widget.isDarkMode;

    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      child: Column(
        children: [
          // Bootstrap Header styled with linear gradient and application brand
          _buildDrawerHeader(context, isDark),

          // Drawer content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              children: [
                // Navigation Section Header (similar to Bootstrap sidebar header)
                _buildSidebarLabel(context, 'NAVIGATION'),

                // Navigation Item: Home
                _buildDrawerItem(
                  context: context,
                  icon: Icons.dashboard_rounded,
                  title: 'Home / Dashboard',
                  isSelected: currentIndex == 0,
                  onTap: () {
                    ref.read(navigationProvider.notifier).setIndex(0);
                    Navigator.of(context).pop(); // Close drawer
                  },
                ),
                
                // Navigation Item: Settings
                _buildDrawerItem(
                  context: context,
                  icon: Icons.settings_rounded,
                  title: 'Settings & Config',
                  isSelected: currentIndex == 1,
                  onTap: () {
                    ref.read(navigationProvider.notifier).setIndex(1);
                    Navigator.of(context).pop(); // Close drawer
                  },
                ),

                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight, height: 1),
                const SizedBox(height: 16),

                // Bootstrap Profile Dropdown option
                _buildSidebarLabel(context, 'USER ACCOUNT'),
                _buildProfileDropdown(context, authState, isDark),

                const SizedBox(height: 16),
                const Divider(color: AppColors.borderLight, height: 1),
                const SizedBox(height: 16),

                // System Actions Section
                _buildSidebarLabel(context, 'PREFERENCES'),

                // Theme Toggle Item styled as inline list-group-item
                _buildThemeToggleItem(context, isDark),

                // About application option
                _buildDrawerItem(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: 'About Template',
                  isSelected: false,
                  onTap: () {
                    Navigator.of(context).pop();
                    _showAboutDialog(context, isDark);
                  },
                ),
              ],
            ),
          ),

          // Drawer footer with app branding and bootstrap label
          _buildDrawerFooter(context, isDark),
        ],
      ),
    );
  }

  // Header inspired by Bootstrap Navbar Dark branding
  Widget _buildDrawerHeader(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.85),
            AppColors.secondary.withOpacity(0.9),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.architecture_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Template Core',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Bootstrap v5.3 Sidebar',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Sidebar section labels
  Widget _buildSidebarLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, bottom: 8.0, top: 4.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  // A helper that creates list items styled like Bootstrap .list-group-item
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Bootstrap styling parameters
    final activeBg = AppColors.primary.withOpacity(0.12);
    final activeBorderColor = AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeBorderColor.withOpacity(0.3) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? AppColors.primary 
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Bootstrap custom expanding dropdown for profile option
  Widget _buildProfileDropdown(BuildContext context, AuthState state, bool isDark) {
    final bgDropdown = isDark ? AppColors.surfaceDark : Colors.white;
    final borderDropdown = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: bgDropdown,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderDropdown),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // The Dropdown Trigger (Bootstrap Dropdown Button)
          InkWell(
            onTap: () {
              setState(() {
                _isProfileExpanded = !_isProfileExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
              child: Row(
                children: [
                  // Profile Avatar
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    backgroundImage: state.photoUrl != null ? NetworkImage(state.photoUrl!) : null,
                    child: state.photoUrl == null
                        ? Text(
                            (state.displayName ?? 'U')[0].toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // User Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.displayName ?? 'User Account',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          state.email ?? 'guest@example.com',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Dropdown arrow (Caret)
                  AnimatedRotation(
                    turns: _isProfileExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dropdown Sub-menu items (Animate expand/collapse)
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.topCenter,
              duration: const Duration(milliseconds: 200),
              heightFactor: _isProfileExpanded ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark 
                      ? AppColors.bgDark.withOpacity(0.5) 
                      : AppColors.bgLight.withOpacity(0.8),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    const Divider(height: 1, color: AppColors.borderLight),
                    // Dropdown Item: View Profile details (switches tab)
                    _buildDropdownItem(
                      icon: Icons.person_outline_rounded,
                      title: 'My Profile & Details',
                      onTap: () {
                        ref.read(navigationProvider.notifier).setIndex(1);
                        Navigator.of(context).pop();
                      },
                      isDark: isDark,
                    ),
                    const Divider(height: 1, color: AppColors.borderLight),
                    // Dropdown Item: Account Settings
                    _buildDropdownItem(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Account Settings',
                      onTap: () {
                        ref.read(navigationProvider.notifier).setIndex(1);
                        Navigator.of(context).pop();
                      },
                      isDark: isDark,
                    ),
                    const Divider(height: 1, color: AppColors.borderLight),
                    // Dropdown Item: Logout (styled like Bootstrap danger text dropdown item)
                    _buildDropdownItem(
                      icon: Icons.logout_rounded,
                      title: 'Sign Out Account',
                      onTap: () => _handleLogout(context),
                      isDark: isDark,
                      isDanger: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A single item inside the profile dropdown menu
  Widget _buildDropdownItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    bool isDanger = false,
  }) {
    final color = isDanger
        ? AppColors.error
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: color.withOpacity(0.8), size: 18),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isDanger ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Theme switcher styled as a Bootstrap form switch row
  Widget _buildThemeToggleItem(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            size: 22,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isDark ? 'Light Theme Mode' : 'Dark Theme Mode',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          Switch.adaptive(
            value: isDark,
            onChanged: (val) {
              widget.onToggleTheme();
            },
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // Elegant version info dialog
  void _showAboutDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.architecture_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Template Core',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version 1.0.0 (Bootstrap Side-Drawer)',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'This application template provides modular feature directories, Clean Architecture patterns, Riverpod provider states, and custom animated cards.',
                style: GoogleFonts.inter(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Bootstrap v5.3 Inspired Grid & Styling',
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close Panel',
                style: GoogleFonts.inter(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Footer for the sidebar
  Widget _buildDrawerFooter(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.02),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Powered by Flutter & Riverpod',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2026 Antigravity IDE Engine',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: isDark ? AppColors.textSecondaryDark.withOpacity(0.6) : AppColors.textSecondaryLight.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
