import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ad_banner_widget.dart';
import '../providers/navigation_provider.dart';
import '../providers/quiz_schedule_provider.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import 'dashboard_screen.dart';
import 'quiz_schedule_screen.dart';
import 'result_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const MainShell({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        onToggleTheme: widget.onToggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      QuizScheduleScreen(
        onToggleTheme: widget.onToggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      ResultScreen(
        onToggleTheme: widget.onToggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
      SettingsScreen(
        onToggleTheme: widget.onToggleTheme,
        isDarkMode: widget.isDarkMode,
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.read(quizScheduleProvider.notifier).startScheduleChecker(context);
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      setState(() {
        _screens = [
          DashboardScreen(
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
          QuizScheduleScreen(
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
          ResultScreen(
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
          SettingsScreen(
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AdBannerWidget(isTopBanner: true),
            Expanded(
              child: IndexedStack(
                index: currentIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavigationBarTheme(
              data: NavigationBarThemeData(
                height: 54,
                indicatorColor: AppColors.primary.withOpacity(0.12),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    );
                  }
                  return GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: currentIndex,
                height: 54,
                onDestinationSelected: (index) {
                  ref.read(navigationProvider.notifier).setIndex(index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined, size: 20),
                    selectedIcon: Icon(Icons.home, color: AppColors.primary, size: 20),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.quiz_outlined, size: 20),
                    selectedIcon: Icon(Icons.quiz, color: AppColors.primary, size: 20),
                    label: 'Quiz',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_outlined, size: 20),
                    selectedIcon: Icon(Icons.insights, color: AppColors.primary, size: 20),
                    label: 'Result',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined, size: 20),
                    selectedIcon: Icon(Icons.settings, color: AppColors.primary, size: 20),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
            const AdBannerWidget(isTopBanner: false),
          ],
        ),
      ),
    );
  }
}
