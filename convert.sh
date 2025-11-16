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

echo "[i] Installing application to Simulator..."

xcrun simctl install "07A3BAF5-0D79-47EF-AB8E-3B7C97091CAA" "$APP_PATH_PATCHED"

echo "[i] Done."