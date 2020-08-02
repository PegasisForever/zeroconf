package ca.michaux.peter.zeroconf;

import android.content.Context;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.net.wifi.WifiManager;
import android.util.Log;
import ca.michaux.peter.zeroconf.EventHandler;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import java.io.UnsupportedEncodingException;
import java.net.InetAddress;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.Collections;

public class ZeroconfPlugin implements MethodCallHandler {

    private static final String TAG = "zeroconf";

    public static void registerWith(final Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "ca.michaux.peter.zeroconf");
        final MethodCallHandler handler = new ZeroconfPlugin(registrar);
        channel.setMethodCallHandler(handler);
    }

    private Registrar registrar;
    private EventHandler eventHandler;
    // private WifiManager.MulticastLock multicastLock;
    private NsdManager nsdManager;
    private NsdManager.DiscoveryListener discoveryListener;
    private ArrayList<NsdServiceInfo> resolveQueue = new ArrayList<>();

    ZeroconfPlugin(final Registrar registrar) {
        this.registrar = registrar;

        this.eventHandler = new EventHandler();
        EventChannel eventChannel = new EventChannel(registrar.messenger(), "ca.michaux.peter.zeroconf.events");
        eventChannel.setStreamHandler(this.eventHandler);
    }

    @Override
    public void onMethodCall(final MethodCall call, final Result result) {
        switch (call.method) {
            case "startScan":
                this.onStartScan(call, result);
                break;
            case "stopScan":
                this.onStopScan(call, result);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void onStartScan(final MethodCall call, final Result result) {
        final String type = call.argument("type");
        this.startScan(type);
        result.success(null);
    }

    private void startScan(final String type) {
        if (this.nsdManager == null) {
            this.nsdManager = (NsdManager)this.registrar.activity().getSystemService(Context.NSD_SERVICE);
        }

        this.stopScan();

        // https://github.com/balthazar/react-native-zeroconf/commit/6b02511a81028a8771d4e6c912f8822dcc94a277
        // https://github.com/balthazar/react-native-zeroconf/commit/b06c2044d127147952c0223d82773b104228caca
        // java.lang.SecurityException: WifiService: Neither user 10106 nor current process has android.permission.CHANGE_WIFI_MULTICAST_STATE.
        /*
        if (this.multicastLock == null) {
            WifiManager wifi = (WifiManager)this.registrar.activity().getSystemService(Context.WIFI_SERVICE);
            this.multicastLock = wifi.createMulticastLock("multicastLock");
            this.multicastLock.setReferenceCounted(true);
            this.multicastLock.acquire();
        }
        */

        this.discoveryListener = new NsdManager.DiscoveryListener() {

            @Override
            public void onDiscoveryStarted(final String serviceType) {
                sendTrivialEvent("ScanStarted");
            }

            @Override
            public void onStartDiscoveryFailed(final String serviceType, final int errorCode) {
                sendTrivialEvent("Error");
            }

            @Override
            public void onDiscoveryStopped(final String serviceType) {
                sendTrivialEvent("ScanStopped");
            }

            @Override
            public void onStopDiscoveryFailed(final String serviceType, final int errorCode) {
                sendTrivialEvent("Error");
            }

            @Override
            public void onServiceFound(final NsdServiceInfo nsdServiceInfo) {
                sendServiceEvent("ServiceFound", serviceToMap(nsdServiceInfo, false));
                resolveService(nsdServiceInfo);
            }

            @Override
            public void onServiceLost(NsdServiceInfo nsdServiceInfo) {
                sendServiceEvent("ServiceLost", serviceToMap(nsdServiceInfo, false));
            }
        };

        this.nsdManager.discoverServices(type, NsdManager.PROTOCOL_DNS_SD, this.discoveryListener);
    }

    private void onStopScan(final MethodCall call, final Result result) {
        this.stopScan();
        result.success(null);
    }

    private void stopScan() {
        if (this.discoveryListener != null) {
            this.nsdManager.stopServiceDiscovery(this.discoveryListener);
        }
        this.discoveryListener = null;
        // if (this.multicastLock != null) {
        //     this.multicastLock.release();
        // }
        // this.multicastLock = null;
    }

    private void resolveService(final NsdServiceInfo service) {

        final NsdManager.ResolveListener resolveListener = new NsdManager.ResolveListener() {

            @Override
            public void onResolveFailed(NsdServiceInfo nsdServiceInfo, int errorCode) {
                switch (errorCode) {
                    case NsdManager.FAILURE_ALREADY_ACTIVE:
                        Log.e(TAG, "FAILURE_ALREADY_ACTIVE");
                        // Just try again...
                        resolveService(nsdServiceInfo);
                        return;
                    case NsdManager.FAILURE_INTERNAL_ERROR:
                        Log.e(TAG, "FAILURE_INTERNAL_ERROR");
                        break;
                    case NsdManager.FAILURE_MAX_LIMIT:
                        Log.e(TAG, "FAILURE_MAX_LIMIT");
                        break;
                }
                sendServiceEvent("ServiceNotResolved", serviceToMap(nsdServiceInfo, false));
            }

            @Override
            public void onServiceResolved(NsdServiceInfo nsdServiceInfo) {
                sendServiceEvent("ServiceResolved", serviceToMap(nsdServiceInfo, true));
            }

        };

        this.nsdManager.resolveService(service, resolveListener);
    }

    private void sendTrivialEvent(final String type) {
        final Map<String, Object> map = new HashMap<String, Object>();
        map.put("type", type);
        this.eventHandler.onEvent(map);
    }

    private void sendServiceEvent(final String type, final Map<String, Object> service) {
        final Map<String, Object> map = new HashMap<String, Object>();
        map.put("type", type);
        map.put("service", service);
        this.eventHandler.onEvent(map);
    }

    private Map<String, Object> serviceToMap(final NsdServiceInfo info, final boolean resolved) {

        final Map<String, Object> map = new HashMap<String, Object>();

        if (info == null) {
            return map;
        }

        final String serviceName = info.getServiceName();
        if (serviceName != null) {
            map.put("name", serviceName);
        }

        if (resolved) {

            final InetAddress host = info.getHost();
            if (host != null) {

                final String hostName = host.getHostName();
                if (hostName != null) {
                    map.put("host", host.getHostName());
                }

                final String hostAddress = host.getHostAddress();
                if (hostAddress != null) {
                    final ArrayList<String> addresses = new ArrayList<String>();
                    addresses.add(hostAddress);
                    map.put("addresses", addresses);
                }
            }

            map.put("port", info.getPort());
        }

        return map;
    }

}
