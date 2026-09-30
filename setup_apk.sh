#!/data/data/com.termux/files/usr/bin/bash
# One-time setup: creates the Capacitor + GitHub Actions files for Neon Dash.
# Run this ONCE in a fresh Termux session, from anywhere:  bash ~/neon-dash/setup_apk.sh
# It only writes small text files — nothing is installed or compiled on this phone.

set -e
DIR="$HOME/neon-dash"
mkdir -p "$DIR/android-src" "$DIR/.github/workflows"

cat > "$DIR/package.json" <<'EOF'
{
  "name": "neon-dash",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "@capacitor/android": "^7.0.0",
    "@capacitor/app": "^7.0.0",
    "@capacitor/core": "^7.0.0",
    "@capacitor/haptics": "^7.0.0",
    "@capacitor/preferences": "^7.0.0"
  },
  "devDependencies": {
    "@capacitor/cli": "^7.0.0"
  }
}
EOF

cat > "$DIR/capacitor.config.json" <<'EOF'
{
  "appId": "com.neondash.game",
  "appName": "Neon Dash",
  "webDir": "www"
}
EOF

cat > "$DIR/.gitignore" <<'EOF'
node_modules/
android/
www/
*.apk
*.log
EOF

cat > "$DIR/android-src/MainActivity.java" <<'EOF'
package com.neondash.game;

import android.content.pm.ActivityInfo;
import android.os.Bundle;
import android.view.WindowManager;

import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);

    // Permanent landscape, as designed
    setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);

    // Native wake lock: screen stays awake while the game is running.
    // (The web-screen Wake Lock API is unreliable in a WebView.)
    getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

    // Immersive fullscreen: hide status/nav bars and draw under the camera
    // cutout, so the whole screen belongs to the game.
    WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
    hideSystemBars();
  }

  private void hideSystemBars() {
    WindowInsetsControllerCompat controller =
      WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
    controller.setSystemBarsBehavior(
      WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
    controller.hide(WindowInsetsCompat.Type.systemBars());
  }
}
EOF

cat > "$DIR/.github/workflows/build.yml" <<'EOF'
name: Build Neon Dash APK

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Set up Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'
          cache: 'gradle'

      - name: Install dependencies
        run: npm install --no-audit --no-fund

      - name: Stage the game into www/
        run: |
          mkdir -p www
          cp index.html www/index.html

      - name: Add the Android platform
        run: npx cap add android

      - name: Apply native overrides (landscape lock, keep-screen-on, immersive)
        run: |
          mkdir -p android/app/src/main/java/com/neondash/game
          cp android-src/MainActivity.java android/app/src/main/java/com/neondash/game/MainActivity.java

      - name: Sync web assets and plugins into the native project
        run: npx cap sync android

      - name: Build debug APK
        run: |
          cd android
          chmod +x gradlew
          ./gradlew assembleDebug --no-daemon

      - name: Upload APK artifact
        uses: actions/upload-artifact@v4
        with:
          name: neon-dash-apk
          path: android/app/build/outputs/apk/debug/app-debug.apk
          retention-days: 90
EOF

echo ""
echo "Created:"
echo "  package.json  capacitor.config.json  .gitignore"
echo "  android-src/MainActivity.java"
echo "  .github/workflows/build.yml"
echo ""
echo "Next: push this folder to GitHub, and the APK will build itself."
