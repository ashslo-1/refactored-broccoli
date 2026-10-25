package me.efesser.flauncher;

import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.telephony.TelephonyCallback;

import androidx.annotation.RequiresApi;

import java.util.Map;

import io.flutter.plugin.common.EventChannel;

@RequiresApi(api = Build.VERSION_CODES.S)
public class TelephonyCallbackImpl extends TelephonyCallback
        implements TelephonyCallback.DataConnectionStateListener
{
    private final EventChannel.EventSink _eventSink;
    private final Handler _handler = new Handler(Looper.getMainLooper());

    public TelephonyCallbackImpl(EventChannel.EventSink eventSink)
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
