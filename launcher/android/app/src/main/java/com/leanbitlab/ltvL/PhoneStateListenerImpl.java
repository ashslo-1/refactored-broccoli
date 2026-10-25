package com.leanbitlab.ltvL;

import android.os.Handler;
import android.os.Looper;
import android.telephony.PhoneStateListener;

import java.util.Map;

import io.flutter.plugin.common.EventChannel;

public class PhoneStateListenerImpl extends PhoneStateListener
{
    private final EventChannel.EventSink _eventSink;
    private final Handler _handler = new Handler(Looper.getMainLooper());

    public  PhoneStateListenerImpl(EventChannel.EventSink eventSink)
    {
        _eventSink = eventSink;
    }

    @Override
    public void onDataConnectionStateChanged(int state, int networkType)
    {
        _handler.post(() -> {
            try {
                _eventSink.success(new java.util.HashMap<String, Object>() {{ put("name", "CELLULAR_STATE_CHANGED"); put("arguments", networkType); }});
            } catch (Exception ignored) {}
        });
    }
}
