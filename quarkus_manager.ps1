# ============================================
#  GESTOR DE PROYECTOS QUARKUS (Arquetipo Maven)
# ============================================

$csvPath = Join-Path $PSScriptRoot "archetype_catalog.csv"
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

function Write-Cmd($cmd) {
    Write-Host "  > $cmd" -ForegroundColor DarkGray
}

# ── Validar CSV ───────────────────────────────
if (-not (Test-Path $csvPath)) {
    Write-Err "No se encontro archetype_catalog.csv en $PSScriptRoot"
    Write-Info "Crea el archivo con columnas: Alias,ArchetypeGroupId,ArchetypeArtifactId,ArchetypeVersion,ArchetypeCatalog,ExtraParams,Descripcion"
    Read-Host "Presiona Enter para salir"
    exit
}

$archetypes = @(Import-Csv $csvPath)

if ($archetypes.Count -eq 0) {
    Write-Err "El CSV esta vacio. Agrega al menos un arquetipo."
    Read-Host "Presiona Enter para salir"
    exit
}

# ── Detectar Maven ────────────────────────────
function Find-MvnExe {
    $m2 = $env:M2_HOME
    if ($m2) {
        $cmd = Join-Path $m2 "bin\mvn.cmd"
        if (Test-Path $cmd) { return $cmd }
        $bat = Join-Path $m2 "bin\mvn.bat"
        if (Test-Path $bat) { return $bat }
    }
    # Intentar desde PATH
    $found = Get-Command mvn -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }

    return $null
}

function Assert-Maven {
    $mvn = Find-MvnExe
    if ($mvn) { return $mvn }

    Write-Err "Maven no encontrado. M2_HOME no esta definido y mvn no esta en PATH."

    # Ofrecer configurar desde maven_paths.csv
    if (Test-Path $mavenCsvPath) {
        $mavens = @(Import-Csv $mavenCsvPath)
        if ($mavens.Count -gt 0) {
            Write-Host ""
            Write-Info "Maven disponibles en maven_paths.csv:"
            for ($i = 0; $i -lt $mavens.Count; $i++) {
                Write-Host "  $($i+1)) $($mavens[$i].Alias) - $($mavens[$i].MavenHome)" -ForegroundColor Yellow
            }
            Write-Host "  0) Cancelar" -ForegroundColor White
            Write-Host ""
            $sel = Read-Host "  Selecciona Maven a usar"
            if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $mavens.Count) {
                $chosen = $mavens[[int]$sel - 1]
                $env:M2_HOME = $chosen.MavenHome
                $env:PATH = "$($chosen.MavenHome)\bin;$env:PATH"
                Write-OK "M2_HOME = $($chosen.MavenHome)"
                return Find-MvnExe
            }
        }
    }

    Write-Err "No se puede continuar sin Maven."
    return $null
}

# ── Seleccionar arquetipo ─────────────────────
function Select-Archetype {
    Write-Title "ARQUETIPOS DISPONIBLES"
    Write-Host ""
    Write-Host "  #   Alias                    Descripcion" -ForegroundColor White
    Write-Host "  --- ------------------------ ----------------------------------------" -ForegroundColor DarkGray

    for ($i = 0; $i -lt $archetypes.Count; $i++) {
        $a = $archetypes[$i]
        $num = ($i + 1).ToString().PadLeft(3)
        $alias = $a.Alias.PadRight(24)
        Write-Host "  $num $alias $($a.Descripcion)" -ForegroundColor Green
    }

    Write-Host ""

    if ($archetypes.Count -eq 1) {
        Write-Info "Solo hay un arquetipo configurado, se usara automaticamente."
        return $archetypes[0]
    }

    $sel = Read-Host "  Selecciona arquetipo (1-$($archetypes.Count))"

    if ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $archetypes.Count) {
        return $archetypes[[int]$sel - 1]
    }

    Write-Err "Seleccion invalida."
    return $null
}

# ── Pedir datos del proyecto ──────────────────
function Read-ProjectInfo {
    Write-Title "DATOS DEL PROYECTO"
    Write-Host ""

    $groupId = Read-Host "  groupId (ej: com.empresa.miapp)"
    if (-not $groupId) {
        Write-Err "groupId es obligatorio."
        return $null
    }

    $artifactId = Read-Host "  artifactId (ej: mi-servicio)"
    if (-not $artifactId) {
        Write-Err "artifactId es obligatorio."
        return $null
    }

    $defaultVersion = "1.0.0-SNAPSHOT"
    $version = Read-Host "  version [$defaultVersion]"
    if (-not $version) { $version = $defaultVersion }

    $defaultPackage = $groupId
    $package = Read-Host "  package [$defaultPackage]"
    if (-not $package) { $package = $defaultPackage }

    return @{
        GroupId    = $groupId
        ArtifactId = $artifactId
        Version    = $version
        Package    = $package
    }
}

# ── Seleccionar directorio destino ────────────
function Select-OutputDir {
    $default = (Get-Location).Path
    $dir = Read-Host "  Directorio destino [$default]"
    if (-not $dir) { $dir = $default }

    if (-not (Test-Path $dir)) {
        $crear = Read-Host "  El directorio no existe. Crearlo? (s/n) [s]"
        if ($crear -eq "n") { return $null }
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-OK "Directorio creado: $dir"
    }

    return $dir
}

# ── Generar proyecto ──────────────────────────
function New-QuarkusProject {
    $mvn = Assert-Maven
    if (-not $mvn) { return }

    $archetype = Select-Archetype
    if (-not $archetype) { return }

    $project = Read-ProjectInfo
    if (-not $project) { return }

    $outputDir = Select-OutputDir
    if (-not $outputDir) { return }

    # Construir comando
    $args = @(
        "archetype:generate"
        "-DarchetypeGroupId=$($archetype.ArchetypeGroupId)"
        "-DarchetypeArtifactId=$($archetype.ArchetypeArtifactId)"
        "-DarchetypeVersion=$($archetype.ArchetypeVersion)"
        "-DgroupId=$($project.GroupId)"
        "-DartifactId=$($project.ArtifactId)"
        "-Dversion=$($project.Version)"
        "-Dpackage=$($project.Package)"
        "-DinteractiveMode=false"
    )

    # Agregar catalogo si esta definido
    if ($archetype.ArchetypeCatalog -and $archetype.ArchetypeCatalog.Trim() -ne "") {
        $args += "-DarchetypeCatalog=$($archetype.ArchetypeCatalog)"
    }

    # Agregar parametros extra si existen
    if ($archetype.ExtraParams -and $archetype.ExtraParams.Trim() -ne "") {
        $extras = $archetype.ExtraParams -split ";"
        foreach ($extra in $extras) {
            if ($extra.Trim() -ne "") {
                $args += "-D$($extra.Trim())"
            }
        }
    }

    # Mostrar resumen
    Write-Title "RESUMEN"
    Write-Host ""
    Write-Host "  Arquetipo:" -ForegroundColor DarkGray
    Write-Host "    GroupId:    $($archetype.ArchetypeGroupId)" -ForegroundColor Yellow
    Write-Host "    ArtifactId: $($archetype.ArchetypeArtifactId)" -ForegroundColor Yellow
    Write-Host "    Version:    $($archetype.ArchetypeVersion)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Proyecto:" -ForegroundColor DarkGray
    Write-Host "    GroupId:    $($project.GroupId)" -ForegroundColor White
    Write-Host "    ArtifactId: $($project.ArtifactId)" -ForegroundColor White
    Write-Host "    Version:    $($project.Version)" -ForegroundColor White
    Write-Host "    Package:    $($project.Package)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Destino:    $outputDir" -ForegroundColor White
    Write-Host ""

    # Mostrar comando completo
    $cmdDisplay = "$mvn $($args -join ' ')"
    Write-Cmd $cmdDisplay
    Write-Host ""

    $confirm = Read-Host "  Generar proyecto? (s/n) [s]"
    if ($confirm -eq "n") {
        Write-Info "Operacion cancelada."
        return
    }

    # Ejecutar
    Write-Host ""
    Write-Info "Generando proyecto..."
    Write-Host ""

    Push-Location $outputDir
    try {
        & $mvn $args 2>&1 | ForEach-Object {
            $line = $_
            if ($line -match "BUILD SUCCESS") {
                Write-Host "  $line" -ForegroundColor Green
            } elseif ($line -match "BUILD FAILURE|ERROR") {
                Write-Host "  $line" -ForegroundColor Red
            } else {
                Write-Host "  $line"
            }
        }

        $projectDir = Join-Path $outputDir $project.ArtifactId
        if (Test-Path $projectDir) {
            Write-Host ""
            Write-OK "Proyecto generado en: $projectDir"
        } else {
            Write-Host ""
            Write-Err "No se encontro la carpeta del proyecto. Revisa la salida de Maven."
        }
    } finally {
        Pop-Location
    }
}

# ── Listar arquetipos ─────────────────────────
function Show-Archetypes {
    Write-Title "ARQUETIPOS CONFIGURADOS"
    Write-Host ""
    Write-Host "  #   Alias                    GroupId                          ArtifactId                       Version" -ForegroundColor White
    Write-Host "  --- ------------------------ -------------------------------- -------------------------------- ----------" -ForegroundColor DarkGray

    for ($i = 0; $i -lt $archetypes.Count; $i++) {
        $a = $archetypes[$i]
        $num = ($i + 1).ToString().PadLeft(3)
        $alias = $a.Alias.PadRight(24)
        $gid = $a.ArchetypeGroupId.PadRight(32)
        $aid = $a.ArchetypeArtifactId.PadRight(32)
        Write-Host "  $num $alias $gid $aid $($a.ArchetypeVersion)" -ForegroundColor Green
    }

    if ($archetypes.Count -gt 0) {
        Write-Host ""
        Write-Host "  Descripcion:" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $archetypes.Count; $i++) {
            Write-Host "    $($i+1)) $($archetypes[$i].Descripcion)" -ForegroundColor Yellow
        }
    }
    Write-Host ""
}

# ── Menu principal ────────────────────────────
function Show-Menu {
    while ($true) {
        Write-Title "GESTOR DE PROYECTOS QUARKUS"
        Write-Host ""
        Write-Host "  1) Crear nuevo proyecto" -ForegroundColor White
        Write-Host "  2) Ver arquetipos configurados" -ForegroundColor White
        Write-Host "  0) Salir" -ForegroundColor White
        Write-Host ""

        $opcion = Read-Host "  Opcion"

        switch ($opcion) {
            "1" { New-QuarkusProject }
            "2" { Show-Archetypes }
            "0" { Write-Info "Hasta luego!"; return }
            default { Write-Err "Opcion no valida." }
        }
    }
}

# ── Inicio ────────────────────────────────────
Show-Menu
