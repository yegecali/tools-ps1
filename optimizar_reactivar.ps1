# ============================================
#  REACTIVAR SERVICIOS - Restaurar Windows
# ============================================

# StartType values: 2 = Automatic, 3 = Manual, 4 = Disabled

$services = @(
    # Telemetria Microsoft
    @{ Name = "DiagTrack";                Label = "Telemetria Microsoft";            Start = 2 },
    @{ Name = "InventorySvc";             Label = "Telemetria Microsoft";            Start = 2 },
    @{ Name = "whesvc";                   Label = "Telemetria Microsoft";            Start = 2 },
    # Telemetria SQL Server
    @{ Name = "SQLTELEMETRY";             Label = "Telemetria SQL Server";           Start = 2 },
    @{ Name = "SSISTELEMETRY170";         Label = "Telemetria SQL Server";           Start = 2 },
    # Telemetria Intel
    @{ Name = "dptftcs";                  Label = "Telemetria Intel";                Start = 2 },
    # Rendimiento
    @{ Name = "SysMain";                  Label = "Superfetch";                      Start = 2 },
    # Innecesarios
    @{ Name = "TrkWks";                   Label = "Link Tracking";                   Start = 2 },
    @{ Name = "MapsBroker";               Label = "Mapas offline Windows";           Start = 2 },
    @{ Name = "DoSvc";                    Label = "Delivery Optimization";           Start = 2 },
    # ASUS
    @{ Name = "ArmouryCrateService";      Label = "ASUS Armoury Crate";             Start = 2 },
    @{ Name = "ArmouryCrateControlInterface"; Label = "ASUS Armoury Crate Interface"; Start = 2 },
    @{ Name = "LightingService";          Label = "ASUS AURA RGB";                  Start = 2 },
    @{ Name = "ROG Live Service";         Label = "ASUS ROG Live";                  Start = 2 },
    @{ Name = "ASUSSystemAnalysis";       Label = "ASUS System Analysis";           Start = 2 },
    @{ Name = "ASUSSystemDiagnosis";      Label = "ASUS System Diagnosis";          Start = 2 }
)

Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  REACTIVANDO SERVICIOS..." -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow

foreach ($svc in $services) {
    $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($s) {
        # Restaurar via registro y Set-Service
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)" -Name Start -Value $svc.Start -ErrorAction SilentlyContinue
        $startType = if ($svc.Start -eq 2) { "Automatic" } elseif ($svc.Start -eq 3) { "Manual" } else { "Disabled" }
        Set-Service -Name $svc.Name -StartupType $startType -ErrorAction SilentlyContinue
        Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
        $result = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
        Write-Host "  [OK] $($svc.Name) - Estado: $($result.Status)" -ForegroundColor Green
    } else {
        Write-Host "  [--] $($svc.Name) - No encontrado" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Listo. Servicios restaurados correctamente." -ForegroundColor Yellow
Write-Host "Presiona Enter para cerrar."
Read-Host
