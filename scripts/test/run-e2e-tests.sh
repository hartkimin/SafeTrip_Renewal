#!/bin/bash
# SafeTrip E2E Integration Test Runner
# Prerequisites:
#   1. Android emulator running (or physical device connected)
#   2. Firebase Emulator Suite running (firebase emulators:start)
#   3. NestJS backend running (cd safetrip-server-api && npm run dev)

set -e

echo "=== SafeTrip E2E Integration Tests ==="
echo ""

# Check prerequisites
echo "[1/3] Checking prerequisites..."

# Check Android device/emulator
if ! adb devices | grep -q "device$"; then
  echo "ERROR: No Android device/emulator detected. Start an emulator first."
  exit 1
fi
echo "  ✓ Android device detected"

# Check backend server
if curl -s http://localhost:3001/api/v1/version > /dev/null 2>&1; then
  echo "  ✓ Backend server running on port 3001"
else
  echo "  WARNING: Backend server not detected on port 3001"
fi

echo ""
echo "[2/3] Running integration tests..."
echo ""

cd "$(dirname "$0")/../../safetrip-mobile"

# Run all flows or a specific flow
if [ -n "$1" ]; then
  echo "Running flow: $1"
  flutter test "integration_test/flows/$1" --no-pub
else
  echo "Running all flows..."
  flutter test integration_test/app_test.dart --no-pub
fi

echo ""
echo "[3/3] Tests complete!"
