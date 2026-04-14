$services = @(
    "DiagTrack",
    "SQLTELEMETRY",
    "SSISTELEMETRY170",
    "dptftcs",
    "InventorySvc",
    "whesvc",
    "SysMain",
    "TrkWks",
    "MapsBroker",
    "DoSvc",
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
        Set-Service -Name $svc -StartupType Disabled
        $result = Get-Service -Name $svc
        Write-Host "[$($result.StartType)] $svc - Estado: $($result.Status)"
    } else {
        Write-Host "[NO ENCONTRADO] $svc"
    }
}

Write-Host "`nListo. Presiona Enter para cerrar."
Read-Host
