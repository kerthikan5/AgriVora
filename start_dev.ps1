#!/usr/bin/env pwsh
<#
    AgriVora — All-in-One Localhost Dev Launcher
    ─────────────────────────────────────────────
    • Starts the FastAPI backend on localhost:8000
    • Runs `adb reverse` so the Android device treats 127.0.0.1:8000 as the PC
    • Launches the Flutter app

    Usage:
        .\start_dev.ps1

    Requirements:
        • Android SDK platform-tools (adb.exe)
        • Python venv in backend\.venv  (or backend\venv)
        • Flutter SDK on PATH
#>

# ─── Paths ─────────────────────────────────────────────────────────────────────
$ROOT        = $PSScriptRoot
$BACKEND_DIR = Join-Path $ROOT "backend"
$FRONTEND_DIR = Join-Path $ROOT "frontend"
$ADB         = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

# Prefer the hidden .venv, fall back to venv
$PYTHON = $null
foreach ($venvName in @(".venv", "venv")) {
    $candidate = Join-Path $BACKEND_DIR "$venvName\Scripts\python.exe"
    if (Test-Path $candidate) {
        $PYTHON = $candidate
        break
    }
}
if (-not $PYTHON) {
    # Last resort: use system Python
    $PYTHON = "py"
}

# ─── Banner ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║     AgriVora · Localhost Dev Launcher    ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Backend  : http://127.0.0.1:8000" -ForegroundColor Cyan
Write-Host "  LAN IP   : http://192.168.8.106:8000" -ForegroundColor Cyan
Write-Host "  Python   : $PYTHON" -ForegroundColor DarkGray
Write-Host ""

# ─── Step 1: Start Backend ─────────────────────────────────────────────────────
Write-Host "[1/3] Starting FastAPI backend on 0.0.0.0:8000..." -ForegroundColor Yellow

# Kill any existing uvicorn process on port 8000 (clean restart)
$existingProc = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty OwningProcess -Unique
if ($existingProc) {
    foreach ($pid in $existingProc) {
        Write-Host "      Stopping existing process on port 8000 (PID $pid)..." -ForegroundColor DarkYellow
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 1000
}

# Launch backend in a new minimized PowerShell window
$backendCmd = "Set-Location '$BACKEND_DIR'; " +
              "Write-Host '[Backend] Starting...' -ForegroundColor Green; " +
              "& '$PYTHON' -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000; " +
              "Write-Host '[Backend] Stopped. Press any key to close.' -ForegroundColor Red; " +
              "Read-Host"

Start-Process powershell -ArgumentList "-NoLogo", "-Command", $backendCmd `
    -WindowStyle Normal

Write-Host "      ✅ Backend starting in new window..." -ForegroundColor Green
Write-Host "      ⏳ Waiting 4 seconds for backend to boot..." -ForegroundColor DarkGray
Start-Sleep -Seconds 4

# Quick health check
try {
    $resp = Invoke-RestMethod -Uri "http://127.0.0.1:8000/health" -TimeoutSec 5
    if ($resp.success -eq $true) {
        Write-Host "      ✅ Backend healthy: $($resp.data)" -ForegroundColor Green
    }
} catch {
    Write-Host "      ⚠️  Backend health check failed — it may still be loading." -ForegroundColor Yellow
    Write-Host "         (The TensorFlow CNN model takes 30-60 s on first cold start)" -ForegroundColor DarkGray
}

Write-Host ""

# ─── Step 2: adb reverse ───────────────────────────────────────────────────────
Write-Host "[2/3] Setting up adb reverse (phone → localhost:8000)..." -ForegroundColor Yellow

if (Test-Path $ADB) {
    # Show connected devices
    $devices = & $ADB devices 2>&1
    Write-Host ""
    Write-Host $devices -ForegroundColor DarkGray
    Write-Host ""

    # Run adb reverse for the backend port
    $result = & $ADB reverse tcp:8000 tcp:8000 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "      ✅ adb reverse tcp:8000 tcp:8000  →  OK" -ForegroundColor Green
        Write-Host "         Phone 127.0.0.1:8000 now tunnels to this PC" -ForegroundColor DarkGray
    } else {
        Write-Host "      ⚠️  adb reverse failed: $result" -ForegroundColor Yellow
        Write-Host "         Falling back to LAN IP: 192.168.8.104:8000" -ForegroundColor Yellow
        Write-Host "         Make sure the phone is on the same Wi-Fi network." -ForegroundColor DarkGray
    }
} else {
    Write-Host "      ⚠️  adb.exe not found at:" -ForegroundColor Yellow
    Write-Host "         $ADB" -ForegroundColor DarkGray
    Write-Host "         Skipping adb reverse — app will try LAN IP (192.168.8.104:8000)" -ForegroundColor Yellow
}

Write-Host ""

# ─── Step 3: Flutter run ───────────────────────────────────────────────────────
Write-Host "[3/3] Launching Flutter app..." -ForegroundColor Yellow
Write-Host ""

Set-Location $FRONTEND_DIR
flutter run
