# Scripts de Administración y Optimización para Windows 11

Colección de scripts PowerShell para gestión de entornos de desarrollo (Java, Maven, Kafka) y optimización del sistema en Windows 11.

---

## Gestores de Entorno

### `java_manager.ps1`

Gestor interactivo de versiones de Java y Maven con administración de certificados. Todas las variables de entorno se guardan a nivel de usuario (no requiere admin).

| Opción | Función                                              |
| ------ | ---------------------------------------------------- |
| 1      | Ver JDKs disponibles                                 |
| 2      | Cambiar versión de Java (`JAVA_HOME` + `PATH`)       |
| 3      | Ver Maven disponibles                                |
| 4      | Cambiar versión de Maven (`M2_HOME` + `PATH`)        |
| 5      | Instalar certificados desde carpeta (1 JDK)          |
| 6      | Instalar certificados desde carpeta (todos los JDKs) |
| 7      | Ver certificados instalados                          |
| 8      | Eliminar certificado                                 |

- Configuración via CSV: `java_paths.csv` y `maven_paths.csv`
- Soporta `mvn.cmd` (Maven moderno) y `mvn.bat` (Maven legacy)
- Si `JAVA_HOME` o `M2_HOME` no están definidos, ofrece configurarlos automáticamente
- Los certificados se colocan en la carpeta `cert/`

### `kafka_manager.ps1`

Gestor interactivo de Apache Kafka en modo KRaft (sin Zookeeper). Abre servidor, productor y consumidor en ventanas PowerShell independientes.

| Opción | Función                                                         |
| ------ | --------------------------------------------------------------- |
| 1      | Iniciar Kafka (formatea KRaft automáticamente si es necesario)  |
| 2      | Detener Kafka                                                   |
| 3      | Crear tópico                                                    |
| 4      | Listar tópicos                                                  |
| 5      | Describir tópico                                                |
| 6      | Eliminar tópico                                                 |
| 7      | Abrir productor (nueva ventana)                                 |
| 8      | Abrir consumidor (nueva ventana)                                |
| 9      | Gestionar consumer groups (listar, describir, resetear offsets) |
| 10     | Ver configuración de Kafka                                      |

- Configuración via CSV: `kafka_paths.csv`
- Usa `subst` para mapear paths cortos y evitar el límite de 8191 caracteres de CMD
- Propaga `JAVA_HOME` a las ventanas hijas via `-EncodedCommand`
- Usa `Get-CimInstance` en lugar de `wmic` (compatible con Windows 11)

### `quarkus_manager.ps1`

Generador de proyectos Quarkus usando arquetipos Maven corporativos. La configuración del arquetipo se define en CSV y el usuario solo introduce los datos del proyecto.

| Opción | Función                     |
| ------ | --------------------------- |
| 1      | Crear nuevo proyecto        |
| 2      | Ver arquetipos configurados |

- Configuración via CSV: `archetype_catalog.csv`
- Detecta Maven automáticamente desde `M2_HOME` o `PATH`; si no lo encuentra ofrece seleccionar desde `maven_paths.csv`
- Pide solo: `groupId`, `artifactId`, `version` y `package`
- Permite elegir directorio destino (crea la carpeta si no existe)
- Muestra resumen y comando completo antes de ejecutar
- Soporta parámetros extra del arquetipo via columna `ExtraParams` (separados por `;`)

### Archivos CSV

| Archivo                 | Columnas                                                                                                   | Propósito                        |
| ----------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------- |
| `java_paths.csv`        | Alias, JavaHome, Descripcion                                                                               | Rutas a instalaciones de JDK     |
| `maven_paths.csv`       | Alias, MavenHome, Descripcion                                                                              | Rutas a instalaciones de Maven   |
| `kafka_paths.csv`       | Alias, KafkaHome, Descripcion                                                                              | Rutas a instalaciones de Kafka   |
| `archetype_catalog.csv` | Alias, ArchetypeGroupId, ArchetypeArtifactId, ArchetypeVersion, ArchetypeCatalog, ExtraParams, Descripcion | Arquetipos Maven para generación |

---

## Scripts de Optimización

> **Requisito:** Ejecutar como **Administrador**.

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
# Gestores (no requieren admin)
.\java_manager.ps1
.\kafka_manager.ps1
.\quarkus_manager.ps1

# Optimización (requiere admin)
.\optimizar_desactivar.ps1
.\optimizar_reactivar.ps1
.\limpieza_optimizacion.ps1
```

## Estructura

```
├── java_manager.ps1          # Gestor de Java/Maven/Certificados
├── java_paths.csv             # Config JDKs
├── maven_paths.csv            # Config Maven
├── cert/                      # Certificados a instalar (.cer, .crt, .pem)
├── kafka_manager.ps1          # Gestor de Kafka
├── kafka_paths.csv            # Config Kafka
├── quarkus_manager.ps1        # Generador de proyectos Quarkus
├── archetype_catalog.csv      # Config arquetipos Maven
├── optimizar_desactivar.ps1   # Desactivar servicios
├── optimizar_reactivar.ps1    # Reactivar servicios
├── limpieza_optimizacion.ps1  # Limpieza del sistema
├── disable_services.ps1       # Desactivar servicios (simple)
├── disable_services_admin.ps1 # Desactivar servicios (admin)
└── services_list.csv          # Lista de servicios del sistema
```

## Advertencia

Los scripts de optimización modifican configuraciones del sistema. Revisa la lista de servicios antes de ejecutar y asegúrate de que no necesitas ninguno de ellos. Usa `optimizar_reactivar.ps1` para revertir los cambios si es necesario.
