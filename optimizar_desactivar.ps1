# ============================================
#  DESACTIVAR SERVICIOS - Optimizacion Windows
# ============================================

$services = @(
    # Telemetria Microsoft
    @{ Name = "DiagTrack";                Label = "Telemetria Microsoft" },
    @{ Name = "InventorySvc";             Label = "Telemetria Microsoft" },
    @{ Name = "whesvc";                   Label = "Telemetria Microsoft" },
    # Telemetria SQL Server
    @{ Name = "SQLTELEMETRY";             Label = "Telemetria SQL Server" },
    @{ Name = "SSISTELEMETRY170";         Label = "Telemetria SQL Server" },
    # Telemetria Intel
    @{ Name = "dptftcs";                  Label = "Telemetria Intel" },
    # Rendimiento
    @{ Name = "SysMain";                  Label = "Superfetch (innecesario en SSD)" },
    # Innecesarios
    @{ Name = "TrkWks";                   Label = "Link Tracking (innecesario)" },
    @{ Name = "MapsBroker";               Label = "Mapas offline Windows" },
    @{ Name = "DoSvc";                    Label = "Delivery Optimization (P2P updates)" },
    # ASUS bloat
    @{ Name = "ArmouryCrateService";      Label = "ASUS Armoury Crate" },
    @{ Name = "ArmouryCrateControlInterface"; Label = "ASUS Armoury Crate Interface" },
    @{ Name = "LightingService";          Label = "ASUS AURA RGB" },
    @{ Name = "ROG Live Service";         Label = "ASUS ROG Live" },
    @{ Name = "ASUSSystemAnalysis";       Label = "ASUS System Analysis" },
    @{ Name = "ASUSSystemDiagnosis";      Label = "ASUS System Diagnosis" }
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DESACTIVANDO SERVICIOS..." -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

foreach ($svc in $services) {
    $s = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
    if ($s) {
        if ($s.Status -eq "Running") {
            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        }
        # Usar registro para servicios protegidos
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)" -Name Start -Value 4 -ErrorAction SilentlyContinue
        Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  [OK] $($svc.Name) - $($svc.Label)" -ForegroundColor Green
    } else {
        Write-Host "  [--] $($svc.Name) - No encontrado" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Listo. Servicios desactivados correctamente." -ForegroundColor Cyan
Write-Host "Presiona Enter para cerrar."
Read-Host
