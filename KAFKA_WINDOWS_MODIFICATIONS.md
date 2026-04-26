# Modificaciones de Kafka 4.2.0 para Windows

Este documento describe los cambios que deben hacerse a los binarios de Kafka para que funcione correctamente en Windows 11.

## Archivos Modificados en `C:\bin\kafka_2.13-4.2.0\`

### 1. `bin\windows\kafka-server-start.bat`
**Líneas 27-35 (Detección de Arquitectura):**

Cambiar de:
```batch
FOR /F "tokens=2 delims= " %%A in ('wmic os get osarchitecture ^| findstr /i "64"') do set OS_ARCH=64
IF "%OS_ARCH%"=="64" (
    set KAFKA_HEAP_OPTS=-Xmx1G -Xms1G
) ELSE (
    set KAFKA_HEAP_OPTS=-Xmx512M -Xms512M
)
```

A:
```batch
IF "%PROCESSOR_ARCHITECTURE%"=="x86" (
    rem 32-bit OS
    set KAFKA_HEAP_OPTS=-Xmx512M -Xms512M
) ELSE (
    rem 64-bit OS
    set KAFKA_HEAP_OPTS=-Xmx1G -Xms1G
)
```

**Razón:** Windows 11 eliminó la herramienta `wmic` (Windows Management Instrumentation Command-line). Se utiliza la variable de entorno nativa `%PROCESSOR_ARCHITECTURE%` que está disponible en todas las versiones de Windows.

---

### 2. `bin\windows\kafka-server-stop.bat`
**Línea 17:**

Cambiar de:
```batch
@echo off
rem ... (licencia)
ps ax | grep -i 'kafka.Kafka' | grep -v grep | awk '{print $1}' | xargs kill -SIGTERM
```

A:
```batch
@echo off
rem ... (licencia)
powershell -NoProfile -Command "Get-Process java -ErrorAction SilentlyContinue | Where-Object { try { (Get-CimInstance Win32_Process -Filter ('ProcessId=' + $_.Id) -ErrorAction SilentlyContinue).CommandLine -like '*kafka.Kafka*' } catch { $false } } | Stop-Process -Force"
```

**Razón:** Búsqueda de procesos Kafka específicos usando PowerShell y WMI en lugar de `wmic` que no existe en Windows 11. Asegura que se detiene correctamente el proceso Kafka en lugar de todos los procesos Java.

---

### 3. `config\server.properties`
**Agregar al final (después de la línea 129):**

```properties
# Windows-specific settings to handle file locking
# Delay before attempting to delete a log segment file from the filesystem (in milliseconds)
# This gives Windows time to fully release file locks before deletion is attempted
log.segment.delete.delay.ms=30000

# Time a log segment file needs to be on disk before its eligible for deletion (in milliseconds)
# This prevents files from being deleted immediately after closure
log.delete.delay.ms=30000
```

**Razón:** Windows mantiene bloqueos de archivo más estrictamente que Linux. Kafka intenta mover archivos de índice (.timeindex) a estado .deleted, pero Windows previene esto mientras el archivo está bloqueado. Estos valores añaden un retraso de 30 segundos antes de intentar eliminar segmentos de log, permitiendo que Windows libere los bloqueos de archivo.

---

## Resumen de Problemas Solucionados

| Problema | Archivo | Solución |
|----------|---------|----------|
| `'wmic' is not recognized` | kafka-server-start.bat | Usar `%PROCESSOR_ARCHITECTURE%` |
| Proceso Kafka no se detiene | kafka-server-stop.bat | Usar PowerShell con WMI |
| FileSystemException al mover .timeindex | server.properties | Añadir retardos de eliminación de logs |

---

## Pasos para Aplicar en Nueva Máquina

1. Copiar binarios de Kafka sin cambios
2. Aplicar los tres cambios documentados arriba
3. Ejecutar `kafka_manager.ps1` desde PowerShell

---

## Notas Importantes

- **Windows File Locking:** Windows mantiene archivos bloqueados más tiempo que Linux. Los retrasos son críticos para evitar errores.
- **PowerShell 5.1:** Scripts diseñados para PowerShell 5.1 nativo de Windows 11.
- **Compatibilidad:** Cambios aplican a Windows 10+ y Kafka 4.2.0+

