# ============================================
#  GESTOR DE APACHE KAFKA (KRaft)
# ============================================

$kafkaCsvPath = Join-Path $PSScriptRoot "kafka_paths.csv"
$defaultBootstrapServer = "localhost:9092"

# ── Helpers ───────────────────────────────────
function Write-Title($msg) {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

function Write-OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "  [ERROR] $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "  $msg" -ForegroundColor Yellow }

function Write-Cmd($cmd) {
    $display = $cmd
    if ($script:substDrive -and $script:substOriginalPath) {
        $display = $display -replace [regex]::Escape("$($script:substDrive):"), $script:substOriginalPath
    }
    Write-Host "  > $display" -ForegroundColor DarkGray
}

# ── Subst para paths largos (evita "input line is too long") ──
$script:substDrive = $null
$script:substOriginalPath = $null

function Mount-KafkaDrive($kafkaHome) {
    # Subst solo es necesario para paths largos que causan "input line is too long"
    if ($kafkaHome.Length -lt 80) {
        return $kafkaHome
    }
    Dismount-KafkaDrive
    foreach ($letter in 'K','Q','X','Y','Z','W') {
        if (-not (Test-Path "${letter}:\")) {
            & subst "${letter}:" $kafkaHome 2>$null
            if ($LASTEXITCODE -eq 0 -and (Test-Path "${letter}:\")) {
                $script:substDrive = $letter
                $script:substOriginalPath = $kafkaHome
                Write-Info "Mapeado $kafkaHome -> ${letter}:"
                return "${letter}:"
            }
        }
    }
    Write-Info "No se pudo mapear drive letter. Usando path original."
    return $kafkaHome
}

function Dismount-KafkaDrive {
    if ($script:substDrive) {
        & subst "$($script:substDrive):" /d 2>$null
        $script:substDrive = $null
        $script:substOriginalPath = $null
    }
}

# Limpiar subst al salir del script
$null = Register-EngineEvent PowerShell.Exiting -Action { Dismount-KafkaDrive }

# ── Helper: lanzar PowerShell en nueva ventana sin problemas de quoting ──
function Start-PsWindow {
    param(
        [string]$Title,
        [string]$Script,
        [switch]$Wait
    )
    $lines = @()
    $lines += "`$Host.UI.RawUI.WindowTitle = '$Title'"
    if ($env:JAVA_HOME) {
        $lines += "`$env:JAVA_HOME = '$($env:JAVA_HOME)'"
        $lines += "`$env:PATH = '$($env:JAVA_HOME)\bin;' + `$env:PATH"
    }
    if ($script:substDrive) {
        $lines += "& subst '$($script:substDrive):' '$($script:substOriginalPath)'"
    }
    $lines += $Script
    $fullScript = $lines -join "; "
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($fullScript)
    $encoded = [Convert]::ToBase64String($bytes)
    $noExit = if ($Wait) { @() } else { @("-NoExit") }
    $proc = Start-Process powershell.exe -ArgumentList (@("-NoProfile") + $noExit + @("-EncodedCommand", $encoded)) -PassThru
    if ($Wait) { $proc.WaitForExit(); return $proc.ExitCode }
}

# ── Validar JAVA_HOME ─────────────────────────
function Assert-Java {
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
        return $true
    }
    # Intentar cargar desde java_paths.csv
    $javaCsv = Join-Path $PSScriptRoot "java_paths.csv"
    if (Test-Path $javaCsv) {
        $jdks = @(Import-Csv $javaCsv | Where-Object { Test-Path (Join-Path $_.JavaHome "bin\java.exe") })
        if ($jdks.Count -gt 0) {
            Write-Err "JAVA_HOME no esta configurado. Kafka necesita Java."
            Write-Host ""
            Write-Host "  JDKs disponibles:" -ForegroundColor White
            for ($i = 0; $i -lt $jdks.Count; $i++) {
                Write-Host "  $($i+1)) $($jdks[$i].Alias) - $($jdks[$i].JavaHome)" -ForegroundColor Yellow
            }
            Write-Host "  0) Cancelar" -ForegroundColor White
            Write-Host ""
            $sel = Read-Host "  Selecciona JDK para esta sesion"
            if ($sel -eq "0" -or -not $sel) { return $false }
            $idx = [int]$sel - 1
            if ($idx -lt 0 -or $idx -ge $jdks.Count) { Write-Err "Seleccion invalida."; return $false }
            $jdk = $jdks[$idx]
            $env:JAVA_HOME = $jdk.JavaHome
            $javaBin = Join-Path $jdk.JavaHome "bin"
            $pathParts = $env:PATH -split ";"
            $env:PATH = (@($javaBin) + $pathParts) -join ";"
            Write-OK "JAVA_HOME = $($jdk.JavaHome)"
            Write-Host ""
            return $true
        }
    }
    Write-Err "JAVA_HOME no esta configurado y no se encontro Java."
    Write-Info "Ejecuta primero java_manager.ps1 para configurar Java."
    return $false
}

# ── Validar CSV ───────────────────────────────
if (-not (Test-Path $kafkaCsvPath)) {
    Write-Err "No se encontro kafka_paths.csv en $PSScriptRoot"
    Write-Info "Crea el archivo con columnas: Alias,KafkaHome,Descripcion"
    Read-Host "Presiona Enter para salir"
    exit
}

$kafkas = @(Import-Csv $kafkaCsvPath)
if ($kafkas.Count -eq 0) {
    Write-Err "El CSV esta vacio. Agrega al menos una entrada."
    Read-Host "Presiona Enter para salir"
    exit
}

# ── Seleccionar instancia de Kafka ────────────
function Select-Kafka {
    param([string]$titulo = "Selecciona instancia de Kafka")
    Write-Title $titulo
    Write-Host ""
    Write-Host "  #   Alias            Path                                         Estado" -ForegroundColor White
    Write-Host "  --- ---------------- -------------------------------------------- ------" -ForegroundColor DarkGray

    for ($i = 0; $i -lt $kafkas.Count; $i++) {
        $k = $kafkas[$i]
        $binDir = Join-Path $k.KafkaHome "bin\windows"
        $exists = if (Test-Path $binDir) { "OK" } else { "NO EXISTE" }
        $color = if ($exists -eq "OK") { "Green" } else { "Red" }
        $num = ($i + 1).ToString().PadLeft(3)
        $alias = $k.Alias.PadRight(16)
        $path = $k.KafkaHome.PadRight(44)
        Write-Host "  $num $alias $path " -NoNewline
        Write-Host $exists -ForegroundColor $color
    }

    Write-Host ""
    $sel = Read-Host "  Numero (0 = cancelar)"
    if ($sel -eq "0" -or -not $sel) { return $null }

    $idx = [int]$sel - 1
    if ($idx -lt 0 -or $idx -ge $kafkas.Count) {
        Write-Err "Seleccion invalida."
        return $null
    }

    $selected = $kafkas[$idx]
    $binDir = Join-Path $selected.KafkaHome "bin\windows"
    if (-not (Test-Path $binDir)) {
        Write-Err "El path no existe: $binDir"
        return $null
    }
    return $selected
}

# Si solo hay 1 instancia, seleccionarla automaticamente
function Get-KafkaOrSelect {
    param([string]$titulo = "Selecciona instancia de Kafka")
    if ($kafkas.Count -eq 1) {
        $k = $kafkas[0]
        $binDir = Join-Path $k.KafkaHome "bin\windows"
        if (-not (Test-Path $binDir)) {
            Write-Err "El path no existe: $binDir"
            return $null
        }
        Write-Info "Usando: $($k.Alias) ($($k.KafkaHome))"
        return $k
    }
    return Select-Kafka $titulo
}

function Get-BinDir($kafka) {
    return Join-Path $kafka.KafkaHome "bin\windows"
}

function Get-ShortBinDir($kafka) {
    # Setear KAFKA_LOG4J_OPTS con URI correcto para evitar el error de Log4j2 reconfiguration
    if (-not $env:KAFKA_LOG4J_OPTS) {
        $logConfig = Join-Path $kafka.KafkaHome "config\tools-log4j2.yaml"
        if (Test-Path $logConfig) {
            $env:KAFKA_LOG4J_OPTS = "-Dlog4j2.configurationFile=$(([System.Uri]::new($logConfig)).AbsoluteUri)"
        }
    }
    $short = Mount-KafkaDrive $kafka.KafkaHome
    return Join-Path $short "bin\windows"
}

function Ask-BootstrapServer {
    $bs = Read-Host "  Bootstrap server [$defaultBootstrapServer]"
    if (-not $bs) { $bs = $defaultBootstrapServer }
    return $bs
}

# ══════════════════════════════════════════════
#  1. INICIAR KAFKA (KRaft - sin Zookeeper)
# ══════════════════════════════════════════════
function Start-KafkaServer {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka para iniciar"
    if (-not $kafka) { return }

    $kafkaHome = $kafka.KafkaHome

    # Buscar configuracion KRaft (con path original para Test-Path)
    $kraftConfigOrig = Join-Path $kafkaHome "config\kraft\server.properties"
    if (-not (Test-Path $kraftConfigOrig)) {
        $kraftConfigOrig = Join-Path $kafkaHome "config\server.properties"
    }
    if (-not (Test-Path $kraftConfigOrig)) {
        Write-Err "No se encontro server.properties en config\kraft\ ni config\"
        return
    }

    # Verificar si ya se formateo el log directory
    $logDir = $null
    $configContent = Get-Content $kraftConfigOrig
    foreach ($line in $configContent) {
        if ($line -match "^log\.dirs\s*=\s*(.+)") {
            $logDir = $matches[1].Trim()
            break
        }
    }

    # Montar drive corto para evitar "input line is too long"
    $shortBin = Get-ShortBinDir $kafka
    $shortHome = if ($script:substDrive) { "$($script:substDrive):" } else { $kafkaHome }
    $kraftConfig = $kraftConfigOrig -replace [regex]::Escape($kafkaHome), $shortHome

    # Formatear storage si no existe el directorio de log
    if ($logDir -and -not (Test-Path $logDir)) {
        Write-Info "Directorio de log no existe. Formateando storage KRaft..."

        $storageScript = Join-Path $shortBin "kafka-storage.bat"

        $cmd = "$storageScript random-uuid"
        Write-Cmd $cmd
        $output = & $storageScript random-uuid 2>&1
        $clusterId = ($output | Select-Object -Last 1).ToString().Trim()
        if (-not $clusterId -or $clusterId.Length -lt 10) {
            Write-Err "No se pudo generar cluster ID: $output"
            Dismount-KafkaDrive
            return
        }
        Write-Info "Cluster ID: $clusterId"

        $cmd = "$storageScript format --standalone -t $clusterId -c $kraftConfig"
        Write-Cmd $cmd
        Write-Info "Formateando en nueva ventana..."
        $exitCode = Start-PsWindow -Title "Kafka Format" -Script "& '$storageScript' format --standalone -t $clusterId -c '$kraftConfig'; exit `$LASTEXITCODE" -Wait
        if ($exitCode -ne 0) {
            Write-Err "Error al formatear storage."
            Dismount-KafkaDrive
            return
        }
        Write-OK "Storage formateado."
    }

    # Iniciar Kafka en nueva ventana (mantener subst activo en esa ventana)
    $kafkaStartScript = Join-Path $shortBin "kafka-server-start.bat"

    $cmd = "$kafkaStartScript $kraftConfig"
    Write-Cmd $cmd
    Write-Info "Iniciando Kafka en nueva ventana..."
    Start-PsWindow -Title "Kafka Server" -Script "`$env:KAFKA_LOG4J_OPTS = ''; & '$kafkaStartScript' '$kraftConfig'"
    Dismount-KafkaDrive
    Write-OK "Kafka iniciado en nueva ventana."
}

# ══════════════════════════════════════════════
#  2. DETENER KAFKA
# ══════════════════════════════════════════════
function Stop-KafkaServer {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka para detener"
    if (-not $kafka) { return }

    Write-Info "Buscando procesos de Kafka..."
    $kafkaProcs = Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object {
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue).CommandLine
            $cmdLine -and $cmdLine -match "kafka"
        } catch { $false }
    }

    if (-not $kafkaProcs -or $kafkaProcs.Count -eq 0) {
        Write-Err "No se encontraron procesos de Kafka ejecutandose."
        return
    }

    foreach ($proc in $kafkaProcs) {
        $cmd = "Stop-Process -Id $($proc.Id) -Force"
        Write-Cmd $cmd
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Write-OK "Proceso Kafka (PID $($proc.Id)) detenido."
    }
}

# ══════════════════════════════════════════════
#  3. CREAR TOPICO
# ══════════════════════════════════════════════
function New-KafkaTopic {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka"
    if (-not $kafka) { return }

    $shortBin = Get-ShortBinDir $kafka
    $topicsScript = Join-Path $shortBin "kafka-topics.bat"
    if (-not (Test-Path $topicsScript)) { Write-Err "kafka-topics.bat no encontrado"; return }

    $bs = Ask-BootstrapServer
    $topicName = Read-Host "  Nombre del topico"
    if (-not $topicName) { Write-Err "El nombre es obligatorio."; return }

    $partitions = Read-Host "  Particiones [1]"
    if (-not $partitions) { $partitions = "1" }

    $replication = Read-Host "  Factor de replicacion [1]"
    if (-not $replication) { $replication = "1" }

    $cmd = "$topicsScript --create --topic $topicName --partitions $partitions --replication-factor $replication --bootstrap-server $bs"
    Write-Cmd $cmd
    Write-Host ""
    & $topicsScript --create --topic $topicName --partitions $partitions --replication-factor $replication --bootstrap-server $bs
    Dismount-KafkaDrive
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Topico '$topicName' creado."
    } else {
        Write-Err "Error al crear el topico."
    }
}

# ══════════════════════════════════════════════
#  4. LISTAR TOPICOS
# ══════════════════════════════════════════════
function Show-KafkaTopics {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka"
    if (-not $kafka) { return }

    $shortBin = Get-ShortBinDir $kafka
    $topicsScript = Join-Path $shortBin "kafka-topics.bat"
    if (-not (Test-Path $topicsScript)) { Write-Err "kafka-topics.bat no encontrado"; return }

    $bs = Ask-BootstrapServer

    $cmd = "$topicsScript --list --bootstrap-server $bs"
    Write-Cmd $cmd
    Write-Host ""
    & $topicsScript --list --bootstrap-server $bs | Out-Host
    Dismount-KafkaDrive
}

# ══════════════════════════════════════════════
#  5. DESCRIBIR TOPICO
# ══════════════════════════════════════════════
function Describe-KafkaTopic {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka"
    if (-not $kafka) { return }

    $shortBin = Get-ShortBinDir $kafka
    $topicsScript = Join-Path $shortBin "kafka-topics.bat"
    if (-not (Test-Path $topicsScript)) { Write-Err "kafka-topics.bat no encontrado"; return }

    $bs = Ask-BootstrapServer
    $topicName = Read-Host "  Nombre del topico"
    if (-not $topicName) { Write-Err "El nombre es obligatorio."; return }

    $cmd = "$topicsScript --describe --topic $topicName --bootstrap-server $bs"
    Write-Cmd $cmd
    Write-Host ""
    & $topicsScript --describe --topic $topicName --bootstrap-server $bs | Out-Host
    Dismount-KafkaDrive
}

# ══════════════════════════════════════════════
#  6. ELIMINAR TOPICO
# ══════════════════════════════════════════════
function Remove-KafkaTopic {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka"
    if (-not $kafka) { return }

    $shortBin = Get-ShortBinDir $kafka
    $topicsScript = Join-Path $shortBin "kafka-topics.bat"
    if (-not (Test-Path $topicsScript)) { Write-Err "kafka-topics.bat no encontrado"; return }

    $bs = Ask-BootstrapServer
    $topicName = Read-Host "  Nombre del topico a eliminar"
    if (-not $topicName) { Write-Err "El nombre es obligatorio."; return }

    $confirm = Read-Host "  Confirmar eliminar topico '$topicName'? (s/n)"
    if ($confirm -ne "s") { Write-Info "Cancelado."; return }

    $cmd = "$topicsScript --delete --topic $topicName --bootstrap-server $bs"
    Write-Cmd $cmd
    Write-Host ""
    & $topicsScript --delete --topic $topicName --bootstrap-server $bs
    Dismount-KafkaDrive
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Topico '$topicName' eliminado."
    } else {
        Write-Err "Error al eliminar el topico."
    }
}

# ══════════════════════════════════════════════
#  7. ABRIR PRODUCTOR (nueva ventana)
# ══════════════════════════════════════════════
function Open-KafkaProducer {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka"
    if (-not $kafka) { return }

    $shortBin = Get-ShortBinDir $kafka
    $producerScript = Join-Path $shortBin "kafka-console-producer.bat"
    if (-not (Test-Path $producerScript)) { Write-Err "kafka-console-producer.bat no encontrado"; return }

    $bs = Ask-BootstrapServer
    $topicName = Read-Host "  Topico al que producir"
    if (-not $topicName) { Write-Err "El topico es obligatorio."; return }

    $cmd = "$producerScript --topic $topicName --bootstrap-server $bs"
    Write-Cmd $cmd
    Write-Info "Abriendo productor en nueva ventana..."
    Start-PsWindow -Title "Kafka Producer [$topicName]" -Script "& '$producerScript' --topic $topicName --bootstrap-server $bs"
    Dismount-KafkaDrive
    Write-OK "Productor abierto para topico '$topicName'."
}

# ══════════════════════════════════════════════
#  8. ABRIR CONSUMIDOR (nueva ventana)
# ══════════════════════════════════════════════
function Open-KafkaConsumer {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka"
    if (-not $kafka) { return }

    $shortBin = Get-ShortBinDir $kafka
    $consumerScript = Join-Path $shortBin "kafka-console-consumer.bat"
    if (-not (Test-Path $consumerScript)) { Write-Err "kafka-console-consumer.bat no encontrado"; return }

    $bs = Ask-BootstrapServer
    $topicName = Read-Host "  Topico a consumir"
    if (-not $topicName) { Write-Err "El topico es obligatorio."; return }

    $fromBeginning = Read-Host "  Leer desde el inicio? (s/n) [n]"
    $groupId = Read-Host "  Consumer group (dejar vacio para ninguno)"

    $args = "--topic $topicName --bootstrap-server $bs"
    if ($fromBeginning -eq "s") { $args += " --from-beginning" }
    if ($groupId) { $args += " --group $groupId" }

    $cmd = "$consumerScript $args"
    Write-Cmd $cmd
    Write-Info "Abriendo consumidor en nueva ventana..."
    Start-PsWindow -Title "Kafka Consumer [$topicName]" -Script "& '$consumerScript' $args"
    Dismount-KafkaDrive
    Write-OK "Consumidor abierto para topico '$topicName'."
}

# ══════════════════════════════════════════════
#  9. CREAR / LISTAR CONSUMER GROUPS
# ══════════════════════════════════════════════
function Show-ConsumerGroups {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka"
    if (-not $kafka) { return }

    $shortBin = Get-ShortBinDir $kafka
    $groupsScript = Join-Path $shortBin "kafka-consumer-groups.bat"
    if (-not (Test-Path $groupsScript)) { Write-Err "kafka-consumer-groups.bat no encontrado"; return }

    $bs = Ask-BootstrapServer

    Write-Host ""
    Write-Host "  1) Listar consumer groups" -ForegroundColor White
    Write-Host "  2) Describir consumer group" -ForegroundColor White
    Write-Host "  3) Resetear offsets de un grupo" -ForegroundColor White
    Write-Host "  0) Volver" -ForegroundColor White
    Write-Host ""
    $op = Read-Host "  Opcion"

    switch ($op) {
        "1" {
            $cmd = "$groupsScript --list --bootstrap-server $bs"
            Write-Cmd $cmd
            Write-Host ""
            & $groupsScript --list --bootstrap-server $bs | Out-Host
        }
        "2" {
            $groupId = Read-Host "  Nombre del consumer group"
            if (-not $groupId) { Write-Err "El nombre es obligatorio."; return }
            $cmd = "$groupsScript --describe --group $groupId --bootstrap-server $bs"
            Write-Cmd $cmd
            Write-Host ""
            & $groupsScript --describe --group $groupId --bootstrap-server $bs | Out-Host
        }
        "3" {
            $groupId = Read-Host "  Nombre del consumer group"
            if (-not $groupId) { Write-Err "El nombre es obligatorio."; return }
            $topicName = Read-Host "  Topico (o --all-topics)"
            $resetTo = Read-Host "  Resetear a [--to-earliest / --to-latest / --to-offset N]"
            if (-not $resetTo) { $resetTo = "--to-earliest" }

            $topicArg = if ($topicName -eq "--all-topics") { "--all-topics" } else { "--topic $topicName" }
            $cmd = "$groupsScript --reset-offsets --group $groupId $topicArg $resetTo --execute --bootstrap-server $bs"
            Write-Cmd $cmd
            Write-Host ""
            & $groupsScript --reset-offsets --group $groupId $topicArg.Split(" ") $resetTo.Split(" ") --execute --bootstrap-server $bs | Out-Host
        }
        "0" { Dismount-KafkaDrive; return }
        default { Write-Err "Opcion invalida." }
    }
    Dismount-KafkaDrive
}

# ══════════════════════════════════════════════
#  10. VER CONFIGURACION DE KAFKA
# ══════════════════════════════════════════════
function Show-KafkaConfig {
    $kafka = Get-KafkaOrSelect "Selecciona Kafka"
    if (-not $kafka) { return }

    $kraftConfig = Join-Path $kafka.KafkaHome "config\kraft\server.properties"
    if (-not (Test-Path $kraftConfig)) {
        $kraftConfig = Join-Path $kafka.KafkaHome "config\server.properties"
    }
    if (-not (Test-Path $kraftConfig)) {
        Write-Err "No se encontro server.properties"
        return
    }

    Write-Title "CONFIGURACION: $kraftConfig"
    Write-Host ""
    Get-Content $kraftConfig | Where-Object { $_ -and $_ -notmatch "^\s*#" } | ForEach-Object {
        Write-Host "  $_" -ForegroundColor White
    }
}

# ══════════════════════════════════════════════
#  MENU PRINCIPAL
# ══════════════════════════════════════════════
while ($true) {
    # Verificar Java al inicio de cada iteracion
    if (-not (Assert-Java)) {
        Read-Host "Presiona Enter para continuar"
        continue
    }

    Write-Title "GESTOR DE APACHE KAFKA"
    Write-Host ""
    Write-Host "  ---- Servidor ----" -ForegroundColor DarkGray
    Write-Host "   1) Iniciar Kafka (KRaft)" -ForegroundColor White
    Write-Host "   2) Detener Kafka" -ForegroundColor White
    Write-Host "  ---- Topicos ----" -ForegroundColor DarkGray
    Write-Host "   3) Crear topico" -ForegroundColor White
    Write-Host "   4) Listar topicos" -ForegroundColor White
    Write-Host "   5) Describir topico" -ForegroundColor White
    Write-Host "   6) Eliminar topico" -ForegroundColor White
    Write-Host "  ---- Productor / Consumidor ----" -ForegroundColor DarkGray
    Write-Host "   7) Abrir productor (nueva ventana)" -ForegroundColor White
    Write-Host "   8) Abrir consumidor (nueva ventana)" -ForegroundColor White
    Write-Host "  ---- Consumer Groups ----" -ForegroundColor DarkGray
    Write-Host "   9) Gestionar consumer groups" -ForegroundColor White
    Write-Host "  ---- Config ----" -ForegroundColor DarkGray
    Write-Host "  10) Ver configuracion de Kafka" -ForegroundColor White
    Write-Host "   0) Salir" -ForegroundColor White
    Write-Host ""
    $op = Read-Host "  Opcion"

    switch ($op) {
        "1"  { Start-KafkaServer }
        "2"  { Stop-KafkaServer }
        "3"  { New-KafkaTopic }
        "4"  { Show-KafkaTopics }
        "5"  { Describe-KafkaTopic }
        "6"  { Remove-KafkaTopic }
        "7"  { Open-KafkaProducer }
        "8"  { Open-KafkaConsumer }
        "9"  { Show-ConsumerGroups }
        "10" { Show-KafkaConfig }
        "0"  { Dismount-KafkaDrive; Write-Host ""; exit }
        default { Write-Err "Opcion invalida." }
    }

    Write-Host ""
    Read-Host "Presiona Enter para continuar"
}
