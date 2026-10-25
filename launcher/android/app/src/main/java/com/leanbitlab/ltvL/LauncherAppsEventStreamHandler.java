package com.leanbitlab.ltvL;

import android.content.Context;
import android.content.pm.LauncherApps;
import android.os.UserHandle;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

public class LauncherAppsEventStreamHandler implements EventChannel.StreamHandler
{
    private final LauncherApps _launcherApps;
    private final MainActivity _activity;

    private LauncherApps.Callback _launcherAppsCallback;

    public LauncherAppsEventStreamHandler(MainActivity activity)
    {
        _activity = activity;
        _launcherApps = (LauncherApps) _activity.getSystemService(Context.LAUNCHER_APPS_SERVICE);
    }

    @Override
    public void onCancel(Object arguments)
    {
        if (_launcherApps != null && _launcherAppsCallback != null) {
            try {
                _launcherApps.unregisterCallback(_launcherAppsCallback);
            } catch (Exception e) {
                e.printStackTrace();
            }
            _launcherAppsCallback = null;
        }
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events)
    {
        _launcherAppsCallback = new LauncherAppsCallback(events);
        _launcherApps.registerCallback(_launcherAppsCallback);
    }


    private class LauncherAppsCallback extends LauncherApps.Callback
    {
        private final EventChannel.EventSink _eventSink;

        public LauncherAppsCallback(EventChannel.EventSink eventSink)
        {
            _eventSink = eventSink;
        }

        @Override
        public void onPackageRemoved(String packageName, UserHandle user) {
            _activity.runOnUiThread(() -> {
                try {
                    _eventSink.success(new java.util.HashMap<String, Object>() {{ put("action", "PACKAGE_REMOVED"); put("packageName", packageName); }});
                } catch (Exception ignored) {}
            });
        }

        @Override
        public void onPackageAdded(String packageName, UserHandle user) {
            Map<String, Serializable> application = _activity.getApplication(packageName);

            if (!application.isEmpty()) {
                _activity.runOnUiThread(() -> {
                    try {
                        _eventSink.success(new java.util.HashMap<String, Object>() {{ put("action", "PACKAGE_ADDED"); put("activityInfo", application); }});
                    } catch (Exception ignored) {}
                });
            }
        }

        @Override
        public void onPackageChanged(String packageName, UserHandle user) {
            Map<String, Serializable> application = _activity.getApplication(packageName);

            if (!application.isEmpty()) {
                _activity.runOnUiThread(() -> {
                    try {
                        _eventSink.success(new java.util.HashMap<String, Object>() {{ put("action", "PACKAGE_CHANGED"); put("activityInfo", application); }});
                    } catch (Exception ignored) {}
                });
            }
        }

        @Override
        public void onPackagesAvailable(String[] packageNames, UserHandle user, boolean replacing) {
            List<Map<String, Serializable>> applications = new ArrayList<>(packageNames.length);

            for (String name : packageNames) {
                Map<String, Serializable> application = _activity.getApplication(name);

                if (!application.isEmpty()) {
                    applications.add(application);
                }
            }

            if (!applications.isEmpty()) {
                _activity.runOnUiThread(() -> {
                    try {
                        _eventSink.success(new java.util.HashMap<String, Object>() {{ put("action", "PACKAGES_AVAILABLE"); put("activitiesInfo", applications); }});
                    } catch (Exception ignored) {}
                });
            }
        }

        @Override
        public void onPackagesUnavailable(String[] packageNames, UserHandle user, boolean replacing) {
        }
    }
}
