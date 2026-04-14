# Scripts de Optimización para Windows 11

Colección de scripts PowerShell para optimizar el rendimiento de Windows 11, desactivando servicios innecesarios (telemetría, bloatware ASUS, etc.) y limpiando archivos temporales.

> **Requisito:** Ejecutar todos los scripts como **Administrador**.

---

## Scripts

### `optimizar_desactivar.ps1`

Desactiva servicios innecesarios agrupados por categoría:

| Categoría             | Servicios                                                    |
| --------------------- | ------------------------------------------------------------ |
| Telemetría Microsoft  | DiagTrack, InventorySvc, whesvc                              |
| Telemetría SQL Server | SQLTELEMETRY, SSISTELEMETRY170                               |
| Telemetría Intel      | dptftcs                                                      |
| Rendimiento           | SysMain (Superfetch)                                         |
| Innecesarios          | TrkWks, MapsBroker, DoSvc                                    |
| ASUS bloatware        | ArmouryCrateService, LightingService, ROG Live Service, etc. |

Detiene los servicios activos, los desactiva vía registro (`Start = 4`) y `Set-Service`.

### `optimizar_reactivar.ps1`

Restaura todos los servicios desactivados por `optimizar_desactivar.ps1` a su tipo de inicio **Automático** y los inicia.

### `limpieza_optimizacion.ps1`

Limpieza profunda del sistema:

- Archivos temporales de usuario (`%TEMP%`) y de Windows
- Prefetch y minidumps
- Descargas de Windows Update
- Cache de miniaturas y DNS
- Papelera de reciclaje
- Logs de eventos (Application, System, Security, Setup)
- Cache de Windows Store y Microsoft Edge
- Optimización de disco (TRIM en SSD / desfragmentación en HDD)

Muestra un resumen con el espacio total liberado al finalizar.

### `disable_services.ps1` / `disable_services_admin.ps1`

Versiones anteriores/simplificadas del script de desactivación de servicios. Misma lista de servicios pero sin etiquetas descriptivas ni modificación de registro.

### `services_list.csv`

Exportación CSV de todos los servicios del sistema con nombre, nombre visible, estado y tipo de inicio. Útil como referencia antes de hacer cambios.

---

## Uso

```powershell
# Desactivar servicios
.\optimizar_desactivar.ps1

# Reactivar servicios
.\optimizar_reactivar.ps1

# Limpieza del sistema
.\limpieza_optimizacion.ps1
```

## Advertencia

Estos scripts modifican configuraciones del sistema. Revisa la lista de servicios antes de ejecutar y asegúrate de que no necesitas ninguno de ellos. Usa `optimizar_reactivar.ps1` para revertir los cambios si es necesario.
