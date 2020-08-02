package ca.michaux.peter.zeroconf;

import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.EventChannel;
import java.util.Map;

public class EventHandler implements EventChannel.StreamHandler {

    EventChannel.EventSink sink;

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
        sink = eventSink;
    }

    @Override
    public void onCancel(Object o) {

    }

    public void onEvent(final Map<String, Object> event) {
        Handler handler = new Handler(Looper.getMainLooper());
        handler.post(new Runnable() {
            @Override
            public void run() {
                sink.success(event);
            }
        });
    }

}
