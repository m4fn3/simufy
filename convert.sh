#!/bin/bash
APP_PATH="$1"
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "Usage: $0 /path/to/application.app"
  exit 1
fi

if [ -d "${APP_PATH%.*}_patched.app" ]; then
    rm -rf "${APP_PATH%.*}_patched.app"
fi
APP_PATH_PATCHED="${APP_PATH%.*}_patched.app"

cp -R "$APP_PATH" "$APP_PATH_PATCHED"

echo "[i] Patching binaries..."

./simufy "$APP_PATH_PATCHED"

echo "[i] Codesigning patched application..."

codesign -f -s - "$APP_PATH_PATCHED"/Frameworks/*
codesign -f -s - "$APP_PATH_PATCHED"/PlugIns/*
codesign -f -s - "$APP_PATH_PATCHED"/Extensions/*
codesign -f -s - "$APP_PATH_PATCHED"

BOOTED_UDID=$(xcrun simctl list devices --json | jq -r '.devices[][] | select(.state=="Booted") | .udid' | head -n 1)
if [ -n "$BOOTED_UDID" ]; then
  echo "[i] Installing application to Simulator..."
  xcrun simctl install "$BOOTED_UDID" "$APP_PATH_PATCHED"
fi


echo "[i] Done."