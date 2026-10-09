package de.hfit.android;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.speech.RecognizerIntent;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import org.json.JSONObject;
import java.io.*;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import javax.net.ssl.HttpsURLConnection;

public final class MainActivity extends Activity implements SensorEventListener {
    private WebView web;
    private SharedPreferences prefs;
    private SensorManager sensors;
    private Sensor stepSensor;
    private String exportData;
    private final ExecutorService network = Executors.newSingleThreadExecutor();
    private long lastLookup;
    private static final String ORIGIN = "https://appassets.androidplatform.net";

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        prefs = getSharedPreferences("hfit", MODE_PRIVATE);
        sensors = (SensorManager)getSystemService(SENSOR_SERVICE);
        stepSensor = sensors.getDefaultSensor(Sensor.TYPE_STEP_COUNTER);
        web = new WebView(this);
        web.setBackgroundColor(0xff0e1217);
        web.setOnApplyWindowInsetsListener((view, insets) -> {
            view.setPadding(insets.getSystemWindowInsetLeft(), insets.getSystemWindowInsetTop(), insets.getSystemWindowInsetRight(), insets.getSystemWindowInsetBottom());
            return insets.consumeSystemWindowInsets();
        });
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setGeolocationEnabled(false);
        web.addJavascriptInterface(new Bridge(), "HFitNative");
        web.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                String path = uri.getPath();
                if ("https".equals(uri.getScheme()) && "appassets.androidplatform.net".equals(uri.getHost()) && path != null) {
                    String asset = path.substring(1);
                    if (Arrays.asList("index.html", "app.css", "core.js", "catalog.js", "onboarding.js", "chat.js", "app.js", "icon.png").contains(asset)) {
                        try {
                            String mime = asset.endsWith(".html") ? "text/html" : asset.endsWith(".css") ? "text/css" : asset.endsWith(".png") ? "image/png" : "application/javascript";
                            return new WebResourceResponse(mime, "UTF-8", getAssets().open(asset));
                        } catch (IOException ignored) { }
                    }
                }
                return new WebResourceResponse("text/plain", "UTF-8", 404, "Not Found", Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
            }
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) { return true; }
        });
        setContentView(web);
        web.loadUrl(ORIGIN + "/index.html");
    }
    private void event(String name, JSONObject value) {
        runOnUiThread(() -> { if (!isFinishing()) web.evaluateJavascript("window.NativeEvents && window.NativeEvents(" + JSONObject.quote(name) + "," + value.toString() + ")", null); });
    }
    private JSONObject message(String value) { JSONObject out = new JSONObject(); try { out.put("message", value); } catch (Exception ignored) {} return out; }
    private void fail(String message) { event("error", message(message)); }
    public final class Bridge {
        @JavascriptInterface public String load() { return prefs.getString("diary", ""); }
        @JavascriptInterface public boolean save(String data) {
            if (data == null || data.length() > 4_000_000) return false;
            try { new JSONObject(data); return prefs.edit().putString("diary", data).commit(); } catch (Exception e) { return false; }
        }
        @JavascriptInterface public void speak() {
            runOnUiThread(() -> {
                Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "de-DE");
                intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "Was hast du wann gegessen?");
                try { startActivityForResult(intent, 101); }
                catch (Exception e) { fail("Im Emulator ist keine Spracherkennung installiert. Bitte tippen oder einen Emulator mit Google-Sprachdiensten verwenden."); }
            });
        }
        @JavascriptInterface public void steps() { runOnUiThread(() -> connectSteps()); }
        @JavascriptInterface public void exportBackup(String data) {
            if (data == null || data.length() > 4_000_000) { fail("Sicherung ist zu groß."); return; }
            runOnUiThread(() -> {
                exportData = data;
                Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("application/json").putExtra(Intent.EXTRA_TITLE, "HFit-Android-Sicherung.json");
                try { startActivityForResult(intent, 102); } catch (Exception e) { fail("Der Emulator bietet keinen Dateidialog an."); }
            });
        }
        @JavascriptInterface public void importBackup() {
            runOnUiThread(() -> {
                Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("application/json");
                try { startActivityForResult(intent, 103); } catch (Exception e) { fail("Der Emulator bietet keinen Dateidialog an."); }
            });
        }
        @JavascriptInterface public void lookup(String code) {
            if (code == null || !code.matches("(?:[0-9]{8}|[0-9]{12,14})")) { fail("Bitte einen gültigen Produktcode eingeben."); return; }
            synchronized (MainActivity.this) {
                if (System.currentTimeMillis() - lastLookup < 5000) { fail("Bitte zwischen Produktsuchen fünf Sekunden warten."); return; }
                lastLookup = System.currentTimeMillis();
            }
            network.execute(() -> {
                HttpsURLConnection connection = null;
                try {
                    URL url = new URL("https://world.openfoodfacts.org/api/v2/product/" + code + ".json?fields=product_name,nutriments");
                    connection = (HttpsURLConnection)url.openConnection();
                    connection.setConnectTimeout(15000); connection.setReadTimeout(15000);
                    connection.setRequestProperty("User-Agent", "HFit/1.0 (personal Android test app)");
                    if (connection.getResponseCode() != 200) throw new IOException("Produktdatenbank momentan nicht erreichbar.");
                    JSONObject result;
                    try (InputStream input = connection.getInputStream()) { result = new JSONObject(readLimited(input, 1_000_000)); }
                    result.put("barcode", code); event("product", result);
                } catch (Exception e) { fail("Produktsuche fehlgeschlagen. Prüfe deine Internetverbindung oder ergänze das Produkt manuell."); }
                finally { if (connection != null) connection.disconnect(); }
            });
        }
    }
    private String readLimited(InputStream input, int limit) throws IOException {
        if (input == null) throw new IOException("Keine Datei");
        ByteArrayOutputStream out = new ByteArrayOutputStream(); byte[] buffer = new byte[8192]; int count;
        while ((count = input.read(buffer)) != -1) { if (out.size() + count > limit) throw new IOException("Datei zu groß"); out.write(buffer, 0, count); }
        return out.toString("UTF-8");
    }
    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (result != RESULT_OK || data == null) { if (request == 102) exportData = null; return; }
        try {
            if (request == 101) {
                ArrayList<String> matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
                if (matches != null && !matches.isEmpty()) event("speech", message(matches.get(0)));
            } else if (request == 102 && exportData != null) {
                try (OutputStream out = getContentResolver().openOutputStream(data.getData())) { if (out == null) throw new IOException(); out.write(exportData.getBytes(StandardCharsets.UTF_8)); }
                exportData = null; event("saved", message("Sicherung gespeichert."));
            } else if (request == 103) {
                try (InputStream in = getContentResolver().openInputStream(data.getData())) { event("import", message(readLimited(in, 4_000_000))); }
            }
        } catch (Exception e) { fail("Die Datei konnte nicht gelesen oder geschrieben werden."); }
    }
    private void connectSteps() {
        if (stepSensor == null) { event("steps", message("Kein Schrittsensor verfügbar. Im Emulator kannst du Schritte manuell eintragen.")); return; }
        if (Build.VERSION.SDK_INT >= 29 && checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.ACTIVITY_RECOGNITION}, 104); return;
        }
        if (!sensors.registerListener(this, stepSensor, SensorManager.SENSOR_DELAY_NORMAL)) { event("steps", message("Der Schrittsensor konnte nicht verbunden werden.")); }
    }
    @Override public void onRequestPermissionsResult(int request, String[] names, int[] grants) {
        super.onRequestPermissionsResult(request, names, grants);
        if (request == 104 && grants.length > 0 && grants[0] == PackageManager.PERMISSION_GRANTED) connectSteps();
        else if (request == 104) event("steps", message("Bewegung wurde nicht freigegeben. Manuelle Einträge bleiben möglich."));
    }
    @Override public void onSensorChanged(SensorEvent event) {
        String day = new SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).format(new Date());
        float current = event.values[0];
        float baseline = prefs.getFloat("stepBase", current);
        if (!day.equals(prefs.getString("stepDay", "")) || current < baseline) {
            baseline = current;
            prefs.edit().putString("stepDay", day).putFloat("stepBase", current).apply();
        }
        JSONObject value = message("Schritte seit der heutigen Sensorverbindung; keine rückwirkenden Tagesdaten.");
        try { value.put("count", Math.max(0, (int)(current - baseline))); value.put("day", day); } catch (Exception ignored) {}
        event("steps", value);
    }
    @Override public void onAccuracyChanged(Sensor sensor, int accuracy) {}
    @Override protected void onDestroy() { sensors.unregisterListener(this); network.shutdownNow(); web.removeJavascriptInterface("HFitNative"); web.destroy(); super.onDestroy(); }
    @Override public void onBackPressed() { web.evaluateJavascript("window.handleBack && window.handleBack()", null); }
}
