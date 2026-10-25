package com.leanbitlab.ltvL;

import android.app.Notification;
import android.content.pm.PackageManager;
import android.graphics.PixelFormat;
import android.graphics.drawable.Drawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.WindowManager;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import java.util.ArrayList;
import java.util.List;

public class LauncherNotificationListenerService extends NotificationListenerService {
    public interface NotificationListener {
        void onNotificationChanged();
    }

    private static final List<NotificationListener> listeners = new ArrayList<>();
    private static LauncherNotificationListenerService instance = null;

    public static void registerListener(NotificationListener listener) {
        synchronized (listeners) {
            listeners.add(listener);
        }
    }

    public static void unregisterListener(NotificationListener listener) {
        synchronized (listeners) {
            listeners.remove(listener);
        }
    }

    public static LauncherNotificationListenerService getInstance() {
        return instance;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        notifyListeners();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (instance == this) {
            instance = null;
        }
        notifyListeners();
    }

    @Override
    public void onNotificationPosted(StatusBarNotification sbn) {
        notifyListeners();
        showNotificationPopup(sbn);
    }

    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        notifyListeners();
    }

    private void notifyListeners() {
        synchronized (listeners) {
            for (NotificationListener listener : listeners) {
                listener.onNotificationChanged();
            }
        }
    }

    private boolean canShowPopup() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return android.provider.Settings.canDrawOverlays(this);
        }
        return true;
    }

    private int dpToPx(int dp) {
        return (int) (dp * getResources().getDisplayMetrics().density);
    }

    private void showNotificationPopup(StatusBarNotification sbn) {
        if (sbn == null || sbn.isOngoing()) {
            return;
        }

        android.content.SharedPreferences prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE);
        boolean enabled = prefs.getBoolean("flutter.system_notifications_popup", false);
        if (!enabled) {
            return;
        }

        if (!canShowPopup()) {
            return;
        }

        android.app.Notification notification = sbn.getNotification();
        if (notification == null) return;

        // Filter out service and media transport notifications
        String category = notification.category;
        if (android.app.Notification.CATEGORY_SERVICE.equals(category) ||
            android.app.Notification.CATEGORY_TRANSPORT.equals(category)) {
            return;
        }

        Bundle extras = notification.extras;
        if (extras == null) return;

        // Filter out media sessions (playback)
        if (extras.containsKey(android.app.Notification.EXTRA_MEDIA_SESSION)) {
            return;
        }

        CharSequence titleChar = extras.getCharSequence(Notification.EXTRA_TITLE);
        CharSequence textChar = extras.getCharSequence(Notification.EXTRA_TEXT);

        final String title = titleChar != null ? titleChar.toString().trim() : "";
        final String text = textChar != null ? textChar.toString().trim() : "";

        if (title.isEmpty() && text.isEmpty()) {
            return;
        }

        final String packageName = sbn.getPackageName();
        final PackageManager pm = getPackageManager();
        String appLabel = packageName;
        Drawable appIcon = null;
        try {
            android.content.pm.ApplicationInfo appInfo = pm.getApplicationInfo(packageName, 0);
            appLabel = pm.getApplicationLabel(appInfo).toString().trim();
            appIcon = pm.getApplicationIcon(appInfo);
        } catch (Exception e) {
            e.printStackTrace();
        }

        // Filter out generic app running notifications where title/text are just the app label
        if (title.equalsIgnoreCase(appLabel) && (text.isEmpty() || text.equalsIgnoreCase(appLabel))) {
            return;
        }
        if (title.equalsIgnoreCase(packageName) && (text.isEmpty() || text.equalsIgnoreCase(packageName))) {
            return;
        }

        final String finalAppLabel = appLabel;
        final Drawable finalAppIcon = appIcon;

        final WindowManager windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        if (windowManager == null) return;

        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                try {
                    android.widget.LinearLayout container = new android.widget.LinearLayout(LauncherNotificationListenerService.this);
                    container.setOrientation(android.widget.LinearLayout.HORIZONTAL);
                    container.setGravity(Gravity.CENTER_VERTICAL);
                    int pad = dpToPx(16);
                    container.setPadding(pad, pad, pad, pad);

                    android.graphics.drawable.GradientDrawable background = new android.graphics.drawable.GradientDrawable();
                    background.setColor(android.graphics.Color.parseColor("#E01E1E1E"));
                    background.setCornerRadius(dpToPx(12));
                    background.setStroke(dpToPx(1), android.graphics.Color.parseColor("#44FFFFFF"));
                    container.setBackground(background);

                    android.widget.ImageView iconView = new android.widget.ImageView(LauncherNotificationListenerService.this);
                    if (finalAppIcon != null) {
                        iconView.setImageDrawable(finalAppIcon);
                    }
                    android.widget.LinearLayout.LayoutParams iconParams = new android.widget.LinearLayout.LayoutParams(dpToPx(40), dpToPx(40));
                    iconParams.rightMargin = dpToPx(12);
                    iconView.setLayoutParams(iconParams);
                    container.addView(iconView);

                    android.widget.LinearLayout textContainer = new android.widget.LinearLayout(LauncherNotificationListenerService.this);
                    textContainer.setOrientation(android.widget.LinearLayout.VERTICAL);
                    android.widget.LinearLayout.LayoutParams textContainerParams = new android.widget.LinearLayout.LayoutParams(
                            android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                            android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                    );
                    textContainer.setLayoutParams(textContainerParams);

                    android.widget.TextView titleView = new android.widget.TextView(LauncherNotificationListenerService.this);
                    String headerText = finalAppLabel;
                    if (title != null && !title.isEmpty()) {
                        headerText += " • " + title;
                    }
                    titleView.setText(headerText);
                    titleView.setTextColor(android.graphics.Color.WHITE);
                    titleView.setTextSize(14);
                    titleView.setTypeface(android.graphics.Typeface.DEFAULT_BOLD);
                    textContainer.addView(titleView);

                    if (text != null && !text.isEmpty()) {
                        android.widget.TextView bodyView = new android.widget.TextView(LauncherNotificationListenerService.this);
                        bodyView.setText(text);
                        bodyView.setTextColor(android.graphics.Color.parseColor("#CCCCCC"));
                        bodyView.setTextSize(13);
                        android.widget.LinearLayout.LayoutParams bodyParams = new android.widget.LinearLayout.LayoutParams(
                                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                        );
                        bodyParams.topMargin = dpToPx(4);
                        bodyView.setLayoutParams(bodyParams);
                        textContainer.addView(bodyView);
                    }

                    container.addView(textContainer);

                    int layoutFlag;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        layoutFlag = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY;
                    } else {
                        layoutFlag = WindowManager.LayoutParams.TYPE_PHONE;
                    }

                    WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                            WindowManager.LayoutParams.WRAP_CONTENT,
                            WindowManager.LayoutParams.WRAP_CONTENT,
                            layoutFlag,
                            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                            PixelFormat.TRANSLUCENT
                    );

                    params.gravity = Gravity.TOP | Gravity.END;
                    params.x = dpToPx(24);
                    params.y = dpToPx(24);

                    windowManager.addView(container, params);

                    new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                windowManager.removeView(container);
                            } catch (Exception e) {
                            }
                        }
                    }, 4000);

                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        });
    }
}
