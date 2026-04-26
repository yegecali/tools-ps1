# ============================================
#  GESTOR DE JAVA Y MAVEN
# ============================================

$csvPath = Join-Path $PSScriptRoot "java_paths.csv"
$mavenCsvPath = Join-Path $PSScriptRoot "maven_paths.csv"

function Write-Title($msg) {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

function Write-OK($msg) {
    Write-Host "  [OK] $msg" -ForegroundColor Green
}

function Write-Err($msg) {
    Write-Host "  [ERROR] $msg" -ForegroundColor Red
}

function Write-Info($msg) {
    Write-Host "  $msg" -ForegroundColor Yellow
}

# ── Validar CSV ───────────────────────────────
if (-not (Test-Path $csvPath)) {
    Write-Err "No se encontro java_paths.csv en $PSScriptRoot"
    Write-Info "Crea el archivo con columnas: Alias,JavaHome,Descripcion"
    Read-Host "Presiona Enter para salir"
    exit
}

$jdks = Import-Csv $csvPath

if ($jdks.Count -eq 0) {
    Write-Err "El CSV esta vacio. Agrega al menos una entrada."
    Read-Host "Presiona Enter para salir"
    exit
}

# ── Cargar Maven CSV ──────────────────────────
$mavens = @()
if (Test-Path $mavenCsvPath) {
    $mavens = Import-Csv $mavenCsvPath
}

# ── Mostrar JDKs disponibles ─────────────────
function Show-JDKs {
    Write-Title "JAVA DISPONIBLES"
    Write-Host ""
    Write-Host "  #   Alias            Path                                         Estado" -ForegroundColor White
    Write-Host "  --- ---------------- -------------------------------------------- ------" -ForegroundColor DarkGray

    $current = $env:JAVA_HOME
    for ($i = 0; $i -lt $jdks.Count; $i++) {
        $jdk = $jdks[$i]
        $exists = if (Test-Path (Join-Path $jdk.JavaHome "bin")) { "OK" } else { "NO EXISTE" }
        $active = if ($current -and $jdk.JavaHome -eq $current) { " <-- ACTIVO" } else { "" }
        $color = if ($exists -eq "OK") { "Green" } else { "Red" }
        $num = ($i + 1).ToString().PadLeft(3)
        $alias = $jdk.Alias.PadRight(16)
        $path = $jdk.JavaHome.PadRight(44)
        Write-Host "  $num $alias $path " -NoNewline
        Write-Host "$exists$active" -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "  JAVA_HOME actual: " -NoNewline -ForegroundColor DarkGray
    if ($current) { Write-Host $current -ForegroundColor Yellow }
    else { Write-Host "(no definido)" -ForegroundColor Red }
    Write-Host ""
}

# ── Cambiar JAVA_HOME y PATH ─────────────────
function Set-JavaVersion {
    Show-JDKs
    $sel = Read-Host "  Selecciona numero de JDK (0 = cancelar)"
    if ($sel -eq "0" -or -not $sel) { return }

    if (-not [int]::TryParse($sel, [ref]$idx)) {
        Write-Err "Entrada inválida, ingresa un número."
        return
    }
    $idx--
    if ($idx -lt 0 -or $idx -ge $jdks.Count) {
        Write-Err "Seleccion invalida."
        return
    }

    $jdk = $jdks[$idx]
    $javaHome = $jdk.JavaHome
    $javaBin = Join-Path $javaHome "bin"

    if (-not (Test-Path $javaBin)) {
        Write-Err "El path no existe: $javaBin"
        Write-Info "Verifica el path en java_paths.csv"
        return
    }

    # Cambiar para la sesion actual
    $env:JAVA_HOME = $javaHome

    # Limpiar paths de Java anteriores del PATH y agregar el nuevo
    $pathParts = $env:PATH -split ";"
    $cleanParts = $pathParts | Where-Object {
        $_ -and
        $_ -notmatch "\\java\\|\\jdk|\\jre|\\graalvm" -or
        $_ -eq $javaBin
    }
    if ($javaBin -notin $cleanParts) {
        $cleanParts = @($javaBin) + $cleanParts
    }
    $env:PATH = ($cleanParts | Select-Object -Unique) -join ";"

    # Persistir en variables de entorno del usuario
    Write-Host ""
    $persist = Read-Host "  Guardar permanentemente? (s/n)"
    if ($persist -eq "s") {
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")

        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        $userParts = $userPath -split ";"
        $userClean = $userParts | Where-Object {
            $_ -and $_ -notmatch "\\java\\|\\jdk|\\jre|\\graalvm"
        }
        $userClean = @($javaBin) + $userClean
        [Environment]::SetEnvironmentVariable("PATH", (($userClean | Select-Object -Unique) -join ";"), "User")
        Write-OK "JAVA_HOME guardado permanentemente."
    } else {
        Write-OK "JAVA_HOME cambiado solo para esta sesion."
    }

    # Verificar
    Write-Host ""
    & "$javaBin\java.exe" -version 2>&1 | ForEach-Object { Write-Info $_ }
}

# ══════════════════════════════════════════════
#  MAVEN MANAGER
# ══════════════════════════════════════════════

function Show-Mavens {
    Write-Title "MAVEN DISPONIBLES"

    if ($mavens.Count -eq 0) {
        Write-Err "No hay entradas en maven_paths.csv"
        Write-Info "Crea el archivo con columnas: Alias,MavenHome,Descripcion"
        return
    }

    Write-Host ""
    Write-Host "  #   Alias            Path                                         Estado" -ForegroundColor White
    Write-Host "  --- ---------------- -------------------------------------------- ------" -ForegroundColor DarkGray

    $currentM2 = $env:M2_HOME
    for ($i = 0; $i -lt $mavens.Count; $i++) {
        $mvn = $mavens[$i]
        $mvnCmd = if (Test-Path (Join-Path $mvn.MavenHome "bin\mvn.cmd")) { "OK" } elseif (Test-Path (Join-Path $mvn.MavenHome "bin\mvn.bat")) { "OK" } else { $null }
        $exists = if ($mvnCmd) { "OK" } else { "NO EXISTE" }
        $active = if ($currentM2 -and $mvn.MavenHome -eq $currentM2) { " <-- ACTIVO" } else { "" }
        $color = if ($exists -eq "OK") { "Green" } else { "Red" }
        $num = ($i + 1).ToString().PadLeft(3)
        $alias = $mvn.Alias.PadRight(16)
        $path = $mvn.MavenHome.PadRight(44)
        Write-Host "  $num $alias $path " -NoNewline
        Write-Host "$exists$active" -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "  M2_HOME actual: " -NoNewline -ForegroundColor DarkGray
    if ($currentM2) { Write-Host $currentM2 -ForegroundColor Yellow }
    else {
        Write-Host "(no definido)" -ForegroundColor Red
        Write-Host ""
        $configurar = Read-Host "  M2_HOME no esta definido. Deseas configurarlo ahora? (s/n) [s]"
        if ($configurar -ne "n") {
            Set-MavenVersion -SkipList
            return
        }
    }

    # Mostrar version activa
    $mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
    if ($mvnCmd) {
        Write-Host "  Maven en PATH: " -NoNewline -ForegroundColor DarkGray
        Write-Host $mvnCmd.Source -ForegroundColor Yellow
    }
    Write-Host ""
}

function Set-MavenVersion {
    param([switch]$SkipList)
    if (-not $SkipList) { Show-Mavens }
    if ($mavens.Count -eq 0) { return }

    $sel = Read-Host "  Selecciona numero de Maven (0 = cancelar)"
    if ($sel -eq "0" -or -not $sel) { return }

    if (-not [int]::TryParse($sel, [ref]$idx)) {
        Write-Err "Entrada inválida, ingresa un número."
        return
    }
    $idx--
    if ($idx -lt 0 -or $idx -ge $mavens.Count) {
        Write-Err "Seleccion invalida."
        return
    }

    $mvn = $mavens[$idx]
    $mavenHome = $mvn.MavenHome
    $mavenBin = Join-Path $mavenHome "bin"

    $mvnExe = if (Test-Path (Join-Path $mavenBin "mvn.cmd")) { "mvn.cmd" } elseif (Test-Path (Join-Path $mavenBin "mvn.bat")) { "mvn.bat" } else { $null }
    if (-not $mvnExe) {
        Write-Err "mvn.cmd/mvn.bat no encontrado en: $mavenBin"
        Write-Info "Verifica el path en maven_paths.csv"
        return
    }

    # Cambiar para la sesion actual
    $env:M2_HOME = $mavenHome
    $env:MAVEN_HOME = $mavenHome

    # Limpiar paths de Maven anteriores del PATH y agregar el nuevo
    $pathParts = $env:PATH -split ";"
    $cleanParts = $pathParts | Where-Object {
        $_ -and
        $_ -notmatch "apache-maven|maven\\bin" -or
        $_ -eq $mavenBin
    }
    if ($mavenBin -notin $cleanParts) {
        $cleanParts = @($mavenBin) + $cleanParts
    }
    $env:PATH = ($cleanParts | Select-Object -Unique) -join ";"

    # Persistir
    Write-Host ""
    $persist = Read-Host "  Guardar permanentemente? (s/n)"
    if ($persist -eq "s") {
        [Environment]::SetEnvironmentVariable("M2_HOME", $mavenHome, "User")
        [Environment]::SetEnvironmentVariable("MAVEN_HOME", $mavenHome, "User")

        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        $userParts = $userPath -split ";"
        $userClean = $userParts | Where-Object {
            $_ -and $_ -notmatch "apache-maven|maven\\bin"
        }
        $userClean = @($mavenBin) + $userClean
        [Environment]::SetEnvironmentVariable("PATH", (($userClean | Select-Object -Unique) -join ";"), "User")
        Write-OK "M2_HOME/MAVEN_HOME guardado permanentemente."
    } else {
        Write-OK "Maven cambiado solo para esta sesion."
    }

    # Verificar
    Write-Host ""
    & "$mavenBin\$mvnExe" --version 2>&1 | ForEach-Object { Write-Info $_ }
}

# ── Helpers de keytool ─────────────────────────
$certExtensions = @("*.cer", "*.crt", "*.pem", "*.der", "*.cert")
$defaultStorePass = "changeit"

function Get-Cacerts($javaHome) {
    $cacerts = Join-Path $javaHome "lib\security\cacerts"
    if (-not (Test-Path $cacerts)) {
        $cacerts = Join-Path $javaHome "jre\lib\security\cacerts"
    }
    return $cacerts
}

function Select-JDK($prompt) {
    Show-JDKs
    $sel = Read-Host "  $prompt (0 = cancelar)"
    if ($sel -eq "0" -or -not $sel) { return $null }
    if (-not [int]::TryParse($sel, [ref]$idx)) {
        Write-Err "Entrada inválida, ingresa un número."
        return $null
    }
    $idx--
    if ($idx -lt 0 -or $idx -ge $jdks.Count) {
        Write-Err "Seleccion invalida."
        return $null
    }
    return $jdks[$idx]
}

# ── Instalar certificados desde carpeta ───────
function Install-CertsFromFolder {
    $jdk = Select-JDK "Selecciona JDK donde instalar certificados"
    if (-not $jdk) { return }

    $keytool = Join-Path $jdk.JavaHome "bin\keytool.exe"
    $cacerts = Get-Cacerts $jdk.JavaHome

    if (-not (Test-Path $keytool)) { Write-Err "keytool no encontrado: $keytool"; return }
    if (-not (Test-Path $cacerts)) { Write-Err "cacerts no encontrado para este JDK"; return }

    $certsDir = Read-Host "  Ruta de la carpeta con certificados"
    if (-not (Test-Path $certsDir)) {
        Write-Err "Carpeta no encontrada: $certsDir"
        return
    }

    $certFiles = Get-ChildItem "$certsDir\*" -File -Include $certExtensions -ErrorAction SilentlyContinue
    if ($certFiles.Count -eq 0) {
        Write-Err "No se encontraron certificados (.cer, .crt, .pem, .der, .cert) en: $certsDir"
        return
    }

    Write-Host ""
    Write-Info "JDK: $($jdk.Alias)"
    Write-Info "Cacerts: $cacerts"
    Write-Info "Certificados encontrados: $($certFiles.Count)"
    Write-Host ""

    $ok = 0; $fail = 0
    foreach ($cert in $certFiles) {
        $alias = ([System.IO.Path]::GetFileNameWithoutExtension($cert.Name).ToLower() -replace '[^a-z0-9_-]', '-') + '-' + ([guid]::NewGuid().ToString().Substring(0,8))
        $cmd = "$keytool -importcert -trustcacerts -keystore $cacerts -storepass $defaultStorePass -noprompt -alias $alias -file $($cert.FullName)"
        Write-Host "  > $cmd" -ForegroundColor DarkGray
        & $keytool -importcert -trustcacerts -keystore $cacerts -storepass $defaultStorePass -noprompt -alias $alias -file $cert.FullName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "$($cert.Name) -> alias '$alias'"
            $ok++
        } else {
            Write-Err "$($cert.Name) -> error (puede que ya exista con alias '$alias')"
            $fail++
        }
    }
    Write-Host ""
    Write-Info "Resultado: $ok instalados, $fail fallidos"
}

# ── Instalar certs de carpeta en TODOS los JDKs
function Install-CertsFromFolderAll {
    $certsDir = Read-Host "  Ruta de la carpeta con certificados"
    if (-not (Test-Path $certsDir)) {
        Write-Err "Carpeta no encontrada: $certsDir"
        return
    }

    $certFiles = Get-ChildItem "$certsDir\*" -File -Include $certExtensions -ErrorAction SilentlyContinue
    if ($certFiles.Count -eq 0) {
        Write-Err "No se encontraron certificados en: $certsDir"
        return
    }

    Write-Host ""
    Write-Info "Certificados encontrados: $($certFiles.Count)"
    Write-Host ""

    foreach ($jdk in $jdks) {
        $keytool = Join-Path $jdk.JavaHome "bin\keytool.exe"
        $cacerts = Get-Cacerts $jdk.JavaHome

        if (-not (Test-Path $keytool) -or -not (Test-Path $cacerts)) {
            Write-Err "$($jdk.Alias): keytool o cacerts no encontrado — saltando"
            continue
        }

        Write-Info "--- $($jdk.Alias) ---"
        $ok = 0; $fail = 0
        foreach ($cert in $certFiles) {
            $alias = ([System.IO.Path]::GetFileNameWithoutExtension($cert.Name).ToLower() -replace '[^a-z0-9_-]', '-') + '-' + ([guid]::NewGuid().ToString().Substring(0,8))
            $cmd = "$keytool -importcert -trustcacerts -keystore $cacerts -storepass $defaultStorePass -noprompt -alias $alias -file $($cert.FullName)"
            Write-Host "  > $cmd" -ForegroundColor DarkGray
            & $keytool -importcert -trustcacerts -keystore $cacerts -storepass $defaultStorePass -noprompt -alias $alias -file $cert.FullName 2>$null
            if ($LASTEXITCODE -eq 0) { $ok++ } else { $fail++ }
        }
        Write-OK "$ok instalados, $fail fallidos"
    }
}

# ── Ver certificados instalados ───────────────
function Show-Certificates {
    $jdk = Select-JDK "Selecciona JDK para ver certificados"
    if (-not $jdk) { return }

    $keytool = Join-Path $jdk.JavaHome "bin\keytool.exe"
    $cacerts = Get-Cacerts $jdk.JavaHome

    if (-not (Test-Path $keytool)) { Write-Err "keytool no encontrado: $keytool"; return }
    if (-not (Test-Path $cacerts)) { Write-Err "cacerts no encontrado"; return }

    Write-Host ""
    Write-Info "JDK: $($jdk.Alias)"
    Write-Info "Cacerts: $cacerts"
    Write-Host ""

    Write-Host "  1) Listar todos los certificados" -ForegroundColor White
    Write-Host "  2) Buscar certificado por alias" -ForegroundColor White
    Write-Host "  0) Volver" -ForegroundColor White
    Write-Host ""
    $op = Read-Host "  Opcion"

    switch ($op) {
        "1" {
            Write-Host ""
            & $keytool -list -keystore $cacerts -storepass $defaultStorePass | Out-Host
        }
        "2" {
            $alias = Read-Host "  Alias a buscar"
            Write-Host ""
            & $keytool -list -keystore $cacerts -storepass $defaultStorePass -alias $alias -v 2>&1 | Out-Host
        }
        "0" { return }
        default { Write-Err "Opcion invalida." }
    }
}

# ── Eliminar certificado ──────────────────────
function Remove-Certificate {
    $jdk = Select-JDK "Selecciona JDK donde eliminar certificado"
    if (-not $jdk) { return }

    $keytool = Join-Path $jdk.JavaHome "bin\keytool.exe"
    $cacerts = Get-Cacerts $jdk.JavaHome

    if (-not (Test-Path $keytool)) { Write-Err "keytool no encontrado"; return }
    if (-not (Test-Path $cacerts)) { Write-Err "cacerts no encontrado"; return }

    $alias = Read-Host "  Alias del certificado a eliminar"
    if (-not $alias) { Write-Err "El alias es obligatorio."; return }

    Write-Host ""
    Write-Info "Eliminando certificado '$alias'..."
    & $keytool -delete -keystore $cacerts -storepass $defaultStorePass -alias $alias
    if ($LASTEXITCODE -eq 0) {
        Write-OK "Certificado '$alias' eliminado."
    } else {
        Write-Err "Error al eliminar el certificado."
    }
}



# ── Menu principal ────────────────────────────
while ($true) {
    Write-Title "GESTOR DE JAVA Y MAVEN"

    if (-not $env:JAVA_HOME) {
        Write-Host ""
        Write-Err "JAVA_HOME no esta definido."
        $configurar = Read-Host "  Deseas configurarlo ahora? (s/n) [s]"
        if ($configurar -ne "n") {
            Set-JavaVersion
            Write-Host ""
            Read-Host "Presiona Enter para continuar"
            continue
        }
    }

    Write-Host ""
    Write-Host "  ---- Java ----" -ForegroundColor DarkGray
    Write-Host "  1) Ver JDKs disponibles" -ForegroundColor White
    Write-Host "  2) Cambiar version de Java (JAVA_HOME + PATH)" -ForegroundColor White
    Write-Host "  ---- Maven ----" -ForegroundColor DarkGray
    Write-Host "  3) Ver Maven disponibles" -ForegroundColor White
    Write-Host "  4) Cambiar version de Maven (M2_HOME + PATH)" -ForegroundColor White
    Write-Host "  ---- Certificados ----" -ForegroundColor DarkGray
    Write-Host "  5) Instalar certificados desde carpeta (1 JDK)" -ForegroundColor White
    Write-Host "  6) Instalar certificados desde carpeta (TODOS los JDKs)" -ForegroundColor White
    Write-Host "  7) Ver certificados instalados" -ForegroundColor White
    Write-Host "  8) Eliminar certificado" -ForegroundColor White
    Write-Host "  0) Salir" -ForegroundColor White
    Write-Host ""
    $op = Read-Host "  Opcion"

    switch ($op) {
        "1" { Show-JDKs }
        "2" { Set-JavaVersion }
        "3" { Show-Mavens }
        "4" { Set-MavenVersion }
        "5" { Install-CertsFromFolder }
        "6" { Install-CertsFromFolderAll }
        "7" { Show-Certificates }
        "8" { Remove-Certificate }
        "0" { Write-Host ""; exit }
        default { Write-Err "Opcion invalida." }
    }

    Write-Host ""
    Read-Host "Presiona Enter para continuar"
}
