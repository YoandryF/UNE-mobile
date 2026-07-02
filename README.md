# ⚡ UNE Consumo Eléctrico — App Móvil

Aplicación móvil Flutter para el control y registro del consumo eléctrico residencial en Cuba, basada en el tarifario oficial de la Unión Nacional Eléctrica (UNE).

Funciona como complemento de la [versión web](../UNE/) con sincronización opcional y compatibilidad total de datos vía JSON.

## 📱 Características

### 🧮 Calculadora de Factura
- **Modo Normal (kWh → CUP):** Calcula factura por consumo
- **Modo Inverso / Plan de Ahorro (CUP → kWh):** ¿Cuánto puedo consumir con mi presupuesto?
- Desglose detallado por rangos de tarifa
- Recargo automático >500 kWh

### 📊 Registro de Lecturas
- Registro con fecha, hora y lectura en kWh
- Foto de evidencia (cámara o galería)
- Edición de registros con opción de agregar/cambiar/quitar foto
- **Termómetro visual** de consumo vs umbral de alerta
- **Estimación fin de mes** basada en promedio diario
- Alertas de proximidad a 500 kWh y umbral personalizado

### 📈 Análisis y Gráficos
- Gráfico de barras del consumo diario (fl_chart)
- Comparación con mes anterior (% variación)
- Estimación de fin de mes (kWh y CUP proyectados)
- Alerta de proximidad a 500 kWh
- **Top Consumidores** — Gráfico de barras horizontales de equipos ordenados por consumo

### 🔌 Gestión de Equipos
- **Equipos 24/7** (siempre encendidos) — Cálculo automático con descuento de apagones
- **Equipos intermitentes** — Registro de uso con hora inicio/fin
- Validación: máximo 24h por equipo por día
- Botón rápido "24h completo"
- Estimación mensual ajustada por apagones
- Separación visual: permanentes vs intermitentes

### 🔦 Control de Apagones
- Botón toggle "SE FUE LA LUZ / VOLVIÓ LA LUZ"
- Historial de apagones con duración
- Estadísticas: horas totales, promedio/día, racha máxima (30 días)
- **Impacto en cálculos:** Los equipos 24/7 se ajustan automáticamente descontando horas sin electricidad

### 📡 Selector de Metro Contador
- Chips de selección rápida en la parte superior
- Cada metro tiene sus propias lecturas, equipos, gráficas y apagones
- Solo aparece si hay más de un metro configurado

### ⚙️ Configuración
- Tarifas editables (18 rangos)
- Múltiples metros contadores
- Día de corte del ciclo de facturación
- Umbral de alerta personalizable
- Tema claro/oscuro
- URL del servidor para sincronización (opcional)
- Export/Import de datos en JSON

### 💾 Persistencia y Sincronización
- **Offline-first:** Todos los datos se guardan localmente con Hive
- **Sincronización opcional** con servidor Node.js (configurable)
- Indicador visual de estado de sync (offline/syncing/synced/error)
- Cola de operaciones pendientes (se sincronizan cuando hay conexión)
- Compatible con JSON generado por la versión web

## 🚀 Compilación

### Requisitos
- Flutter SDK 3.4+
- Android SDK

### Pasos

```bash
cd une_consumo

# Instalar dependencias
flutter pub get

# Compilar APK release
flutter build apk --release
```

APK generada en: `build/app/outputs/flutter-apk/app-release.apk`

### Generar iconos (si se modifica assets/icon.png)

```bash
dart run flutter_launcher_icons
```

## 📁 Estructura

```
une_consumo/
├── lib/
│   ├── main.dart              # Entry point + HomeScreen + SyncStatusBar
│   ├── models.dart            # TariffConfig, Reading, Equipment, AppConfig
│   ├── db_service.dart        # Persistencia Hive + Export/Import
│   ├── sync_service.dart      # Sincronización con backend (offline-first)
│   ├── tariff_calc.dart       # Cálculo de factura + cálculo inverso
│   ├── theme.dart             # Tema oscuro/claro + widgets estilizados
│   ├── screens/
│   │   ├── calculator_screen.dart  # Calculadora normal + inversa
│   │   ├── readings_screen.dart    # Registro + termómetro + apagones
│   │   ├── chart_screen.dart       # Gráficos + top consumidores
│   │   ├── equipment_screen.dart   # Equipos + log de uso
│   │   └── config_screen.dart      # Configuración + export/import
│   └── widgets/
│       ├── confirm_dialog.dart     # Diálogo de confirmación
│       └── blackouts_widget.dart   # Widget de apagones
├── assets/
│   ├── icon.png               # Ícono de la app
│   ├── icon_foreground.png    # Ícono adaptativo (foreground)
│   └── icon.svg               # Ícono fuente SVG
├── android/                   # Configuración Android
├── pubspec.yaml               # Dependencias
└── README.md
```

## 📦 Dependencias principales

| Paquete | Uso |
|---------|-----|
| hive / hive_flutter | Base de datos local |
| http | Sincronización con servidor |
| fl_chart | Gráficos de barras |
| image_picker | Cámara y galería |
| intl | Formateo de fechas |
| share_plus | Compartir export JSON |
| file_picker | Importar JSON |
| connectivity_plus | Detección de conectividad |
| path_provider | Rutas del sistema |

## 🔄 Formato JSON (Export/Import)

Compatible entre web y APK:

```json
{
  "readings": [
    {"id": "...", "reading": 19680, "date": "2026-06-13", "time": "13:21", "photo": null, "meter": 0, "tariffs": {...}, "createdAt": "...", "updatedAt": "..."}
  ],
  "equipment": [
    {"id": "...", "name": "Refrigerador", "watts": 200, "hours": 24, "meter": 0, "alwaysOn": true}
  ],
  "blackouts": [
    {"id": "...", "tipo": "inicio", "timestamp": 1719500000000, "metroId": 0}
  ],
  "equipment_usage": [
    {"id": "...", "equipId": "...", "date": "2026-06-29", "startTime": "10:00", "endTime": "10:30", "meter": 0}
  ],
  "config": {
    "tariffs": {"ranges": [[100, 0.33], ...], "surcharge": 25},
    "alertThreshold": 450,
    "billCycleDay": 1,
    "meters": ["AMANDA", "YENI"],
    "activeMeter": 0
  }
}
```

## 📊 Tarifario UNE (por defecto)

| Rango | kWh | CUP/kWh |
|-------|-----|---------|
| 1 | 0–100 | 0.33 |
| 2 | 101–150 | 1.07 |
| 3 | 151–200 | 1.43 |
| 4 | 201–250 | 2.46 |
| 5 | 251–300 | 3.00 |
| 6 | 301–350 | 4.00 |
| 7 | 351–400 | 5.00 |
| 8 | 401–450 | 6.00 |
| 9 | 451–500 | 7.00 |
| 10 | 501–600 | 9.20 |
| 11 | 601–700 | 9.45 |
| 12 | 701–1000 | 9.85 |
| 13 | 1001–1800 | 10.80 |
| 14 | 1801–2600 | 11.80 |
| 15 | 2601–3400 | 12.90 |
| 16 | 3401–4200 | 13.95 |
| 17 | 4201–5000 | 15.00 |
| 18 | >5000 | 20.00 |

**Recargo:** 25% sobre kWh que excedan 500.

## 📄 Versión

**v1.1.0** — 2026-07-01

## 📄 Licencia

Uso libre. Proyecto personal para control de consumo eléctrico doméstico.
