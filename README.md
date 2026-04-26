# Scripts de Gestión de Entornos - Windows 11

Colección de scripts PowerShell para gestión de entornos de desarrollo (Java, Maven, Kafka) en Windows 11.

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

### Archivos CSV

| Archivo           | Columnas                              | Propósito                    |
| ----------------- | ------------------------------------- | ---------------------------- |
| `java_paths.csv`  | Alias, JavaHome, Descripcion          | Rutas a instalaciones de JDK |
| `maven_paths.csv` | Alias, MavenHome, Descripcion         | Rutas a instalaciones Maven  |
| `kafka_paths.csv` | Alias, KafkaHome, Descripcion         | Rutas a instalaciones Kafka  |

---

## Uso

```powershell
# Gestores de entorno (no requieren admin)
.\java_manager.ps1
.\kafka_manager.ps1
```

## Estructura

```
├── java_manager.ps1     # Gestor de Java/Maven/Certificados
├── java_paths.csv       # Config JDKs
├── maven_paths.csv      # Config Maven
├── cert/                # Certificados a instalar (.cer, .crt, .pem)
├── kafka_manager.ps1    # Gestor de Kafka
└── kafka_paths.csv      # Config Kafka
```
