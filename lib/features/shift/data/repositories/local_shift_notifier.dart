import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/shift.dart';
import '../../domain/entities/shift_push.dart';
import '../../domain/repositories/shift_notifier.dart';

/// Shift pushes as local notifications (flutter_local_notifications), with
/// the "I'm coming" / "Not today" actions of Notification 05–06.
///
/// Pushes due within [_timerWindow] are shown from a timer (demo timings);
/// later ones are scheduled with the alarm manager, exact when the phone
/// allows it, so they arrive with the app closed.
///
/// TODO(backend): replace the scheduling with FCM pushes from the backend.
class LocalShiftNotifier implements ShiftNotifier {
  LocalShiftNotifier({FlutterLocalNotificationsPlugin? plugin}) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _actions = StreamController<ShiftPushAction>.broadcast();
  final _opened = StreamController<ShiftPush>.broadcast();
  ShiftPush? _launchedFrom;
  final _timers = <ShiftPush, Timer>{};
  Future<ShiftPushAction?>? _ready;

  static const _timerWindow = Duration(minutes: 2);
  static const _category = 'stock_request';

  static const _channel = AndroidNotificationDetails(
    'shift',
    'Shift reminders',
    channelDescription: 'Stock requests before your shift and when your stock is ready',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF009600),
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
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
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
                  'I’m coming',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  ShiftPushAction.notToday.name,
                  'Not today',
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
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null && _actionOf(response) == ShiftPushAction.open) {
      _launchedFrom = _pushOf(response);
    }
    return launch?.didNotificationLaunchApp == true && response != null ? _actionOf(response) : null;
  }

  static ShiftPushAction? _actionOf(NotificationResponse r) {
    final id = r.actionId;
    if (id == null || id.isEmpty) return ShiftPushAction.open;
    return ShiftPushAction.values.where((a) => a.name == id).firstOrNull;
  }

  static ShiftPush? _pushOf(NotificationResponse r) => ShiftPush.values.where((p) => p.name == r.payload).firstOrNull;

  NotificationDetails _details(ShiftPush push, ShiftPushContent content) => NotificationDetails(
    android: AndroidNotificationDetails(
      _channel.channelId,
      _channel.channelName,
      channelDescription: _channel.channelDescription,
      importance: _channel.importance,
      priority: _channel.priority,
      color: _channel.color,
      styleInformation: BigTextStyleInformation(content.body),
      actions: [
        for (final MapEntry(key: action, value: label) in content.actions.entries)
          // Opens the app, which records the reply.
          AndroidNotificationAction(action.name, label, showsUserInterface: true),
      ],
    ),
    iOS: DarwinNotificationDetails(categoryIdentifier: push.hasActions ? _category : null),
  );

  @override
  Future<void> show(ShiftPush push, Shift shift, {PushDetail detail = const PushDetail()}) async {
    if (!_supported) return;
    await init();
    // The reminder takes the first ask's place in the shade.
    if (push == ShiftPush.reminder) await _plugin.cancel(id: ShiftPush.prepareStock.id);
    final content = ShiftPushContent.of(push, shift, detail: detail);
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
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? true;
    final content = ShiftPushContent.of(push, shift);
    await _plugin.zonedSchedule(
      id: push.id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details(push, content),
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
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
    await _plugin.cancel(id: push.id);
  }

  @override
  Stream<ShiftPushAction> get actions => _actions.stream;

  @override
  Stream<ShiftPush> get opened => _opened.stream;

  @override
  ShiftPush? get launchedFrom => _launchedFrom;
}
