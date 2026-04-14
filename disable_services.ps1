$services = @(
    # Telemetria
    "DiagTrack",
    "SQLTELEMETRY",
    "SSISTELEMETRY170",
    "dptftcs",
    "InventorySvc",
    "whesvc",
    # Rendimiento / innecesarios
    "SysMain",
    "TrkWks",
    "MapsBroker",
    "DoSvc",
    # ASUS
    "ArmouryCrateService",
    "ArmouryCrateControlInterface",
    "LightingService",
    "ROG Live Service",
    "ASUSSystemAnalysis",
    "ASUSSystemDiagnosis"
)

foreach ($svc in $services) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s) {
        if ($s.Status -eq "Running") {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        $result = Get-Service -Name $svc -ErrorAction SilentlyContinue
        Write-Host "OK: $svc -> Estado: $($result.Status) | Inicio: $($result.StartType)"
    } else {
        Write-Host "NO ENCONTRADO: $svc"
    }
}
