package org.dartpilot.spike;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbInterface;
import android.hardware.usb.UsbManager;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.SystemClock;
import android.util.Log;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

/**
 * Feasibility spike #104: asks for the UVC cameras, streams them through the native libuvc measurement and reports
 * frame rate, lost frames, CPU and battery. Started from adb with {@code --ei cameras N --ei seconds S} it runs by
 * itself once the cameras are allowed; the result is logged under the tag {@value #TAG}.
 */
public class MainActivity extends Activity {
    static final String TAG = "DartPilotSpike";
    private static final String ACTION_PERMISSION = "org.dartpilot.spike.USB_PERMISSION";
    private static final int UVC_CLASS = 14;

    private UsbManager usb;
    private TextView output;
    private EditText seconds;
    private final List<UsbDeviceConnection> connections = new ArrayList<>();
    private List<UsbDevice> pending = new ArrayList<>();
    private int wanted;

    private final BroadcastReceiver permission = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            askNext();
        }
    };

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        usb = (UsbManager) getSystemService(USB_SERVICE);
        registerReceiver(permission, new IntentFilter(ACTION_PERMISSION), Context.RECEIVER_NOT_EXPORTED);

        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(32, 96, 32, 32);
        seconds = new EditText(this);
        seconds.setText("30");
        seconds.setHint("Sekunden");
        layout.addView(seconds);
        for (int n = 1; n <= 3; n++) {
            final int count = n;
            Button button = new Button(this);
            button.setText(n == 1 ? "1 Kamera messen" : n + " Kameras messen");
            button.setOnClickListener(v -> start(count));
            layout.addView(button);
        }
        output = new TextView(this);
        output.setTextIsSelectable(true);
        ScrollView scroll = new ScrollView(this);
        scroll.addView(output);
        layout.addView(scroll, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        setContentView(layout);

        show(describeCameras());
        Intent launch = getIntent();
        if (launch.hasExtra("cameras")) {
            seconds.setText(String.valueOf(launch.getIntExtra("seconds", 30)));
            start(launch.getIntExtra("cameras", 3));
        }
    }

    @Override
    protected void onDestroy() {
        unregisterReceiver(permission);
        closeAll();
        super.onDestroy();
    }

    private List<UsbDevice> cameras() {
        List<UsbDevice> found = new ArrayList<>();
        for (UsbDevice device : usb.getDeviceList().values()) {
            for (int i = 0; i < device.getInterfaceCount(); i++) {
                UsbInterface intf = device.getInterface(i);
                if (intf.getInterfaceClass() == UVC_CLASS) {
                    found.add(device);
                    break;
                }
            }
        }
        found.sort((a, b) -> a.getDeviceName().compareTo(b.getDeviceName()));
        return found;
    }

    private String describeCameras() {
        StringBuilder text = new StringBuilder("UVC-Kameras: ");
        List<UsbDevice> all = cameras();
        text.append(all.size()).append('\n');
        for (UsbDevice d : all) {
            text.append("  ").append(d.getDeviceName()).append("  ").append(d.getProductName()).append('\n');
        }
        return text.toString();
    }

    private void start(int count) {
        closeAll();
        List<UsbDevice> all = cameras();
        if (all.size() < count) {
            show("Nur " + all.size() + " Kamera(s) gefunden, " + count + " gewünscht.");
            return;
        }
        wanted = count;
        pending = new ArrayList<>(all.subList(0, count));
        askNext();
    }

    /** Asks for the next camera that has no permission yet; runs once all have one. */
    private void askNext() {
        for (UsbDevice device : pending) {
            if (!usb.hasPermission(device)) {
                Intent intent = new Intent(ACTION_PERMISSION).setPackage(getPackageName());
                PendingIntent pi = PendingIntent.getBroadcast(this, 0, intent, PendingIntent.FLAG_MUTABLE);
                usb.requestPermission(device, pi);
                return;
            }
        }
        if (pending.size() == wanted) runMeasurement();
    }

    private void runMeasurement() {
        int[] fds = new int[pending.size()];
        for (int i = 0; i < pending.size(); i++) {
            UsbDeviceConnection connection = usb.openDevice(pending.get(i));
            if (connection == null) {
                show("Kamera " + pending.get(i).getDeviceName() + " ließ sich nicht öffnen.");
                closeAll();
                return;
            }
            connections.add(connection);
            fds[i] = connection.getFileDescriptor();
        }
        pending = new ArrayList<>();
        final int duration = Math.max(5, Integer.parseInt("0" + seconds.getText().toString().trim()));
        show("Messe " + fds.length + " Kamera(s) für " + duration + " s …");
        new Thread(() -> {
            BatteryManager battery = (BatteryManager) getSystemService(BATTERY_SERVICE);
            long chargeBefore = battery.getLongProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER);
            int levelBefore = battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY);
            float temperatureBefore = batteryTemperature();
            long start = SystemClock.elapsedRealtime();
            String result = NativeSpike.run(fds, duration);
            long elapsedMs = SystemClock.elapsedRealtime() - start;
            long chargeAfter = battery.getLongProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER);
            String batteryJson = String.format(java.util.Locale.ROOT,
                    "{\"charge_before_uah\":%d,\"charge_after_uah\":%d,\"drain_ma\":%.0f,\"level_before\":%d,"
                            + "\"level_after\":%d,\"temperature_before_c\":%.1f,\"temperature_after_c\":%.1f}",
                    chargeBefore, chargeAfter, (chargeBefore - chargeAfter) * 3.6 / elapsedMs,
                    levelBefore, battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
                    temperatureBefore, batteryTemperature());
            String report = "{\"cameras_requested\":" + fds.length + ",\"battery\":" + batteryJson
                    + ",\"native\":" + result + "}";
            Log.i(TAG, report);
            runOnUiThread(() -> {
                closeAll();
                show(report);
            });
        }).start();
    }

    private float batteryTemperature() {
        Intent status = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        return status == null ? Float.NaN : status.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) / 10f;
    }

    private void closeAll() {
        for (UsbDeviceConnection c : connections) c.close();
        connections.clear();
    }

    private void show(String text) {
        Log.i(TAG, text);
        output.setText(text);
    }
}
