# ============================================
#  LIMPIEZA Y OPTIMIZACION - Windows 11
# ============================================

function Write-Step($msg) {
    Write-Host "`n>> $msg" -ForegroundColor Cyan
}
function Write-OK($msg) {
    Write-Host "   [OK] $msg" -ForegroundColor Green
}
function Write-Skip($msg) {
    Write-Host "   [--] $msg" -ForegroundColor DarkGray
}

$totalFreed = 0

function Get-FolderSize($path) {
    if (Test-Path $path) {
        return (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    }
    return 0
}

function Remove-FolderContents($path, $label) {
    if (Test-Path $path) {
        $before = Get-FolderSize $path
        Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $after  = Get-FolderSize $path
        $freed  = [math]::Round(($before - $after) / 1MB, 2)
        $script:totalFreed += ($before - $after)
        Write-OK "$label — liberado: $freed MB"
    } else {
        Write-Skip "$label — carpeta no encontrada"
    }
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   LIMPIEZA Y OPTIMIZACION DE WINDOWS" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# ── 1. Temporales de usuario ──────────────────
Write-Step "Temporales de usuario (%TEMP%)"
Remove-FolderContents $env:TEMP "Temp usuario"

# ── 2. Temporales de Windows ──────────────────
Write-Step "Temporales de Windows"
Remove-FolderContents "C:\Windows\Temp" "Windows\Temp"

# ── 3. Prefetch ───────────────────────────────
Write-Step "Prefetch"
Remove-FolderContents "C:\Windows\Prefetch" "Prefetch"

# ── 4. Minidumps de crashes ───────────────────
Write-Step "Minidumps (crashdumps)"
Remove-FolderContents "C:\Windows\Minidump"       "Minidump"
Remove-FolderContents "$env:LOCALAPPDATA\CrashDumps" "CrashDumps usuario"

# ── 5. Logs de Windows Update ─────────────────
Write-Step "Logs de Windows Update"
Remove-FolderContents "C:\Windows\SoftwareDistribution\Download" "WU Downloads"

# ── 6. Thumbnails cache ───────────────────────
Write-Step "Cache de miniaturas"
Remove-FolderContents "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" "Thumbnails cache"

# ── 7. Cache DNS ──────────────────────────────
Write-Step "Flush cache DNS"
ipconfig /flushdns | Out-Null
Write-OK "DNS cache limpiado"

# ── 8. Papelera de reciclaje ──────────────────
Write-Step "Papelera de reciclaje"
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-OK "Papelera vaciada"
} catch {
    Write-Skip "No se pudo vaciar la papelera"
}

# ── 9. Logs de eventos de Windows ─────────────
Write-Step "Logs de eventos de Windows (vaciando)"
$logs = @("Application", "System", "Security", "Setup")
foreach ($log in $logs) {
    try {
        wevtutil cl $log 2>$null
        Write-OK "Log '$log' limpiado"
    } catch {
        Write-Skip "Log '$log' — sin permisos"
    }
}

# ── 10. Cache de Windows Store ────────────────
Write-Step "Cache de Windows Store"
try {
    wsreset.exe | Out-Null
    Write-OK "Windows Store cache reiniciado"
} catch {
    Write-Skip "No se pudo limpiar Store cache"
}

# ── 11. Archivos temporales de Internet (Edge)─
Write-Step "Cache de Microsoft Edge"
$edgeCache = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\Cache_Data"
Remove-FolderContents $edgeCache "Edge Cache"

# ── 12. Optimizar disco (TRIM si es SSD) ──────
Write-Step "Optimizacion de disco"
$drive = $env:SystemDrive.TrimEnd(":")
try {
    $diskType = (Get-PhysicalDisk | Where-Object { $_.DeviceId -eq "0" }).MediaType
    if ($diskType -eq "SSD") {
        Optimize-Volume -DriveLetter $drive -ReTrim -Verbose 2>$null
        Write-OK "SSD detectado — TRIM ejecutado en disco $drive"
    } else {
        Optimize-Volume -DriveLetter $drive -Defrag 2>$null
        Write-OK "HDD detectado — Desfragmentacion iniciada en disco $drive"
    }
} catch {
    Write-Skip "No se pudo optimizar el disco"
}

# ── RESUMEN ───────────────────────────────────
$totalMB = [math]::Round($totalFreed / 1MB, 2)
$totalGB = [math]::Round($totalFreed / 1GB, 2)
$display = if ($totalGB -ge 1) { "$totalGB GB" } else { "$totalMB MB" }

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "   LIMPIEZA COMPLETADA" -ForegroundColor Green
Write-Host "   Espacio liberado total: $display" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Presiona Enter para cerrar."
Read-Host
