package com.prosperlink.ninzo_rider

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

/**
 * Shift pushes on Android, drawn with the app's own layout so "I'm coming"
 * and "Not today" look like the app's buttons (the system's action row can't
 * be coloured). Scheduled ones wait in AlarmManager and are kept in
 * SharedPreferences, so a reboot doesn't lose them. A tap opens MainActivity
 * with [ACTION_TAP]; it tells Dart which button.
 */
object ShiftPushes {
    const val ACTION_TAP = "ninzo.PUSH_TAP"
    const val EXTRA_ID = "pushId"
    const val EXTRA_ACTION = "pushAction"
    const val EXTRA_PAYLOAD = "pushPayload"

    private const val CHANNEL_ID = "shift"
    private const val PREFS = "ninzo.shift_pushes"
    private const val BRAND = 0xFF009600.toInt()

    /** One push, as Dart sends it. */
    data class Push(
        val id: Int,
        val title: String,
        val body: String,
        val payload: String,
        val actions: List<Pair<String, String>>,
        val channelName: String,
        val channelDescription: String,
    ) {
        fun toJson(at: Long): String = JSONObject()
            .put("id", id).put("title", title).put("body", body).put("payload", payload)
            .put("channelName", channelName).put("channelDescription", channelDescription).put("at", at)
            .put("actions", JSONArray(actions.map { JSONObject().put("id", it.first).put("label", it.second) }))
            .toString()

        companion object {
            @Suppress("UNCHECKED_CAST")
            fun of(args: Map<String, Any?>) = Push(
                id = (args["id"] as Number).toInt(),
                title = args["title"] as String,
                body = args["body"] as String,
                payload = args["payload"] as String,
                actions = (args["actions"] as List<Map<String, String>>).map { it.getValue("id") to it.getValue("label") },
                channelName = args["channelName"] as String,
                channelDescription = args["channelDescription"] as String,
            )

            fun fromJson(text: String): Pair<Push, Long> {
                val j = JSONObject(text)
                val actions = j.getJSONArray("actions")
                return Push(
                    id = j.getInt("id"),
                    title = j.getString("title"),
                    body = j.getString("body"),
                    payload = j.getString("payload"),
                    actions = (0 until actions.length()).map {
                        actions.getJSONObject(it).let { a -> a.getString("id") to a.getString("label") }
                    },
                    channelName = j.getString("channelName"),
                    channelDescription = j.getString("channelDescription"),
                ) to j.getLong("at")
            }
        }
    }

    fun show(context: Context, push: Push) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, push.channelName, NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = push.channelDescription },
            )
        }
        val small = RemoteViews(context.packageName, R.layout.notification_shift).apply {
            setTextViewText(R.id.push_title, push.title)
            setTextViewText(R.id.push_body, push.body)
        }
        val big = withButtons(context, push, R.layout.notification_shift_big)
        // The pop-up over the screen is short: its own, tighter layout.
        val headsUp = withButtons(context, push, R.layout.notification_shift_headsup)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(BRAND)
            .setContentTitle(push.title)
            .setContentText(push.body)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(small)
            .setCustomBigContentView(big)
            .setCustomHeadsUpContentView(headsUp)
            .setContentIntent(tap(context, push, "", 0))
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .build()
        manager.notify(push.id, notification)
    }

    /** [layout] with the title, the message and a button for each reply. */
    private fun withButtons(context: Context, push: Push, layout: Int) = RemoteViews(context.packageName, layout).apply {
        setTextViewText(R.id.push_title, push.title)
        setTextViewText(R.id.push_body, push.body)
        setViewVisibility(R.id.push_buttons, if (push.actions.isEmpty()) View.GONE else View.VISIBLE)
        listOf(R.id.push_primary, R.id.push_secondary).forEachIndexed { i, view ->
            val action = push.actions.getOrNull(i)
            setViewVisibility(view, if (action == null) View.GONE else View.VISIBLE)
            if (action != null) {
                setTextViewText(view, action.second)
                setOnClickPendingIntent(view, tap(context, push, action.first, i + 1))
            }
        }
    }

    /** Opens the app with [action] ("" for the notification itself). */
    private fun tap(context: Context, push: Push, action: String, slot: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(ACTION_TAP)
            .putExtra(EXTRA_ID, push.id)
            .putExtra(EXTRA_ACTION, action)
            .putExtra(EXTRA_PAYLOAD, push.payload)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(
            context,
            push.id * 10 + slot,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun schedule(context: Context, push: Push, at: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(push.id.toString(), push.toJson(at)).apply()
        arm(context, push.id, at)
    }

    private fun arm(context: Context, id: Int, at: Long) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val pending = alarm(context, id)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarms.canScheduleExactAlarms()) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        } else {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
        }
    }

    private fun alarm(context: Context, id: Int): PendingIntent = PendingIntent.getBroadcast(
        context,
        id,
        Intent(context, ShiftPushReceiver::class.java).putExtra(EXTRA_ID, id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun cancel(context: Context, id: Int) {
        context.getSystemService(AlarmManager::class.java).cancel(alarm(context, id))
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(id.toString()).apply()
        context.getSystemService(NotificationManager::class.java).cancel(id)
    }

    /** The alarm went off: shows the saved push. */
    fun fire(context: Context, id: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val saved = prefs.getString(id.toString(), null) ?: return
        prefs.edit().remove(id.toString()).apply()
        show(context, Push.fromJson(saved).first)
    }

    /** After a reboot: alarms again; one missed while off shows now. */
    fun rearm(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        for ((key, value) in prefs.all) {
            val (push, at) = Push.fromJson(value as? String ?: continue)
            if (at > System.currentTimeMillis()) {
                arm(context, push.id, at)
            } else {
                prefs.edit().remove(key).apply()
                show(context, push)
            }
        }
    }
}

/** A scheduled shift push is due. */
class ShiftPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ShiftPushes.fire(context, intent.getIntExtra(ShiftPushes.EXTRA_ID, -1))
    }
}

/** The phone restarted or the app was updated: the alarms are set again. */
class ShiftPushBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        ShiftPushes.rearm(context)
    }
}
