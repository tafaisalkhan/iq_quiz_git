import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../theme/app_colors.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  OverlayEntry? _currentOverlayEntry;
  Timer? _dismissTimer;

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initialize native Android local notifications
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      tz.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          // App opens when user taps system status bar notification
        },
      );

      final androidImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;

      // Automatically schedule a daily native system status bar notification at 10:00 AM
      scheduleNativeDailyNotification(
        id: 999,
        title: 'Daily IQ Quiz Reminder 🧠',
        body: 'Don\'t forget to take your daily IQ quiz today and train your brain!',
        hour: 10,
        minute: 0,
      );
    } catch (_) {}
  }

  /// Displays an immediate native Android system status bar notification
  Future<void> showImmediateNativeNotification({
    required String title,
    required String body,
    int id = 100,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'iq_quiz_channel',
      'IQ Quiz Reminders',
      channelDescription: 'Scheduled quiz assessment notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      await _localNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
      );
    } catch (_) {}
  }

  /// Schedule a native Android system notification even when app is closed / not running
  Future<void> scheduleNativeDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await initialize();

    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'iq_quiz_channel',
      'IQ Quiz Reminders',
      channelDescription: 'Scheduled quiz assessment notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    try {
      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
      await _localNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduled,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  Future<void> cancelNativeNotification(int id) async {
    try {
      await _localNotificationsPlugin.cancel(id);
    } catch (_) {}
  }

  /// Checks and displays the daily notification banner once per day
  Future<void> checkAndShowDailyNotification(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      final lastDate = prefs.getString('last_daily_notification_date');

      if (lastDate != todayStr) {
        await prefs.setString('last_daily_notification_date', todayStr);
        
        // Show native Android status bar notification
        showImmediateNativeNotification(
          id: 888,
          title: 'Daily IQ Assessment Ready 🧠',
          body: 'Your 2 free daily cognitive quiz sessions are unlocked! Train your brain today.',
        );

        if (!context.mounted) return;

        Future.delayed(const Duration(milliseconds: 800), () {
          if (!context.mounted) return;
          showNotification(
            context,
            title: 'Daily IQ Assessment Ready 🧠',
            message: 'Your 2 free daily cognitive quiz sessions are unlocked! Train your brain today.',
            icon: Icons.psychology_rounded,
            duration: const Duration(seconds: 5),
          );
        });
      }
    } catch (_) {}
  }

  /// Displays a premium in-app push notification banner that slides down from the top.
  void showNotification(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Dismiss any active notification first
    dismiss();

    final overlayState = Overlay.of(context);
    
    _currentOverlayEntry = OverlayEntry(
      builder: (context) => _NotificationBanner(
        title: title,
        message: message,
        icon: icon,
        onDismiss: dismiss,
      ),
    );

    overlayState.insert(_currentOverlayEntry!);

    // Auto-dismiss after duration
    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  /// Manually dismisses the active notification banner
  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    
    if (_currentOverlayEntry != null) {
      _currentOverlayEntry!.remove();
      _currentOverlayEntry = null;
    }
  }
}

class _NotificationBanner extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.title,
    required this.message,
    required this.icon,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnimation = Tween<double>(begin: -100, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: mediaQuery.padding.top + 12 + _slideAnimation.value,
          left: 16,
          right: 16,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            _handleDismiss();
          }
        },
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.cardDark.withOpacity(0.85)
                      : AppColors.cardLight.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark.withOpacity(0.5)
                        : AppColors.borderLight.withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.message,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _handleDismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
