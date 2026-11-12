import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../domain/entities/shift.dart';
import '../../../domain/entities/shift_push.dart';
import '../../../domain/repositories/shift_notifier.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

/// Shift pushes as local notifications, with the "I'm coming" / "Not today"
/// replies of Notification 05–06. On Android they're drawn by the app
/// (`ShiftPushes.kt`, channel `ninzo/push`) so the replies look like the app's
/// buttons; on iOS flutter_local_notifications shows them.
///
/// Pushes due within [_timerWindow] are shown from a timer (demo timings);
/// later ones are scheduled with the alarm manager, exact when the phone
/// allows it, so they arrive with the app closed.
///
/// With the rider API the server sends stock ready, spot assigned, orders
/// waiting and shift ending soon (FCM); this shows them while the app is
/// open, and shows the stock request, with its replies, at the plan's times.
class LocalShiftNotifier implements ShiftNotifier {
  LocalShiftNotifier({FlutterLocalNotificationsPlugin? plugin}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _actions = StreamController<ShiftPushAction>.broadcast();
  final _opened = StreamController<ShiftPush>.broadcast();
  ShiftPush? _launchedFrom;
  final _timers = <ShiftPush, Timer>{};
  Future<ShiftPushAction?>? _ready;

  static const _timerWindow = Duration(minutes: 2);
  static const _android = MethodChannel('ninzo/push');

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const _category = 'stock_request';

  static const _channel = AndroidNotificationDetails(
    'shift',
    AppStrings.shiftReminders,
    channelDescription: AppStrings.stockRequestsBeforeYourShiftAnd,
    importance: Importance.high,
    priority: Priority.high,
    icon: AppAssets.notificationIcon,
    color: RiderColors.brand,
  );

  static bool get _supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<ShiftPushAction?> init() => _ready ??= _init();

  Future<ShiftPushAction?> _init() async {
    if (!_supported) return null;
    tz_data.initializeTimeZones();
    // Times are absolute instants, so UTC as the local zone is fine.
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings(AppAssets.notificationIcon),
        iOS: DarwinInitializationSettings(
          // Asked on Onboard 04.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _category,
              actions: [
                DarwinNotificationAction.plain(
                  ShiftPushAction.coming.name,
                  AppStrings.iMComing,
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  ShiftPushAction.notToday.name,
                  AppStrings.notToday,
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final action = _actionOf(r);
        if (action != null) _actions.add(action);
        final push = action == ShiftPushAction.open ? _pushOf(r) : null;
        if (push != null) _opened.add(push);
      },
    );
    if (_isAndroid) {
      // Anything the plugin scheduled before pushes moved to ShiftPushes.kt.
      await _plugin.cancelAll();
      _android.setMethodCallHandler((call) async {
        if (call.method == 'tapped') _tapped((call.arguments as Map).cast<String, Object?>());
      });
      final tap = (await _android.invokeMapMethod<String, Object?>('launch'));
      if (tap == null) return null;
      final action = _actionNamed(tap['action'] as String?);
      if (action == ShiftPushAction.open) _launchedFrom = _pushNamed(tap['payload'] as String?);
      return action;
    }
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null && _actionOf(response) == ShiftPushAction.open) {
      _launchedFrom = _pushOf(response);
    }
    return launch?.didNotificationLaunchApp == true && response != null ? _actionOf(response) : null;
  }

  static ShiftPushAction? _actionOf(NotificationResponse r) => _actionNamed(r.actionId);

  static ShiftPushAction? _actionNamed(String? id) {
    if (id == null || id.isEmpty) return ShiftPushAction.open;
    return ShiftPushAction.values.where((a) => a.name == id).firstOrNull;
  }

  static ShiftPush? _pushOf(NotificationResponse r) => _pushNamed(r.payload);

  static ShiftPush? _pushNamed(String? name) => ShiftPush.values.where((p) => p.name == name).firstOrNull;

  /// A tap on an Android push while the app runs.
  void _tapped(Map<String, Object?> tap) {
    final action = _actionNamed(tap['action'] as String?);
    if (action != null) _actions.add(action);
    final push = action == ShiftPushAction.open ? _pushNamed(tap['payload'] as String?) : null;
    if (push != null) _opened.add(push);
  }

  /// What `ShiftPushes.kt` draws.
  static Map<String, Object?> _androidPush(ShiftPush push, ShiftPushContent content) => {
    'id': push.id,
    'title': content.title,
    'body': content.body,
    'payload': push.name,
    'channelName': AppStrings.shiftReminders,
    'channelDescription': AppStrings.stockRequestsBeforeYourShiftAnd,
    'actions': [
      for (final MapEntry(key: action, value: label) in content.actions.entries) {'id': action.name, 'label': label},
    ],
  };

  NotificationDetails _details(ShiftPush push, ShiftPushContent content) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channel.channelId,
      _channel.channelName,
      channelDescription: _channel.channelDescription,
      importance: _channel.importance,
      priority: _channel.priority,
      icon: _channel.icon,
      color: _channel.color,
      styleInformation: BigTextStyleInformation(content.body),
      actions: [
        for (final MapEntry(key: action, value: label) in content.actions.entries)
          // Opens the app, which records the reply.
          AndroidNotificationAction(action.name, label, showsUserInterface: true, titleColor: RiderColors.brand),
      ],
    ),
    iOS: DarwinNotificationDetails(categoryIdentifier: push.hasActions ? _category : null),
  );

  @override
  Future<void> show(ShiftPush push, Shift shift, {PushDetail detail = const PushDetail()}) async {
    if (!_supported) return;
    await init();
    // The reminder takes the first ask's place in the shade.
    final content = ShiftPushContent.of(push, shift, detail: detail);
    if (_isAndroid) {
      if (push == ShiftPush.reminder) await _android.invokeMethod('cancel', {'id': ShiftPush.prepareStock.id});
      await _android.invokeMethod('show', _androidPush(push, content));
      return;
    }
    if (push == ShiftPush.reminder) await _plugin.cancel(id: ShiftPush.prepareStock.id);
    await _plugin.show(
      id: push.id,
      title: content.title,
      body: content.body,
      notificationDetails: _details(push, content),
      payload: push.name,
    );
  }

  @override
  Future<void> schedule(ShiftPush push, Shift shift, DateTime at) async {
    if (!_supported) return;
    await init();
    await cancel(push);
    final wait = at.difference(DateTime.now());
    if (wait < _timerWindow) {
      _timers[push] = Timer(wait.isNegative ? Duration.zero : wait, () => show(push, shift));
      return;
    }
    final content = ShiftPushContent.of(push, shift);
    if (_isAndroid) {
      await _android.invokeMethod('schedule', {..._androidPush(push, content), 'at': at.millisecondsSinceEpoch});
      return;
    }
    await _plugin.zonedSchedule(
      id: push.id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details(push, content),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: content.title,
      body: content.body,
      payload: push.name,
    );
  }

  @override
  Future<void> cancel(ShiftPush push) async {
    _timers.remove(push)?.cancel();
    if (!_supported) return;
    await init();
    if (_isAndroid) {
      await _android.invokeMethod('cancel', {'id': push.id});
      return;
    }
    await _plugin.cancel(id: push.id);
  }

  @override
  Stream<ShiftPushAction> get actions => _actions.stream;

  @override
  Stream<ShiftPush> get opened => _opened.stream;

  @override
  ShiftPush? get launchedFrom => _launchedFrom;
}
