# ⚡ Consumo Eléctrico UNE - Cuba (Mobile)

App móvil Flutter para el control y registro del consumo eléctrico residencial en Cuba, basada en el tarifario oficial de la UNE.

## 📱 Descargar

Descarga el APK desde [Releases](https://github.com/YoandryF/UNE-mobile/releases).

## 📸 Características

- 🧮 **Calculadora** — Cálculo de factura con desglose por rangos
- 📊 **Registro diario** — Lecturas del metro con foto de evidencia
- 📈 **Gráficos** — Consumo diario, comparación mensual, costo/día
- 🔌 **Equipos** — Registro de electrodomésticos con estimación mensual
- ⚙️ **Configuración** — Tarifas editables, múltiples metros, alertas, tema oscuro/claro
- 💾 **Backup** — Export/Import en JSON
- 📷 **Evidencia** — Foto del metro comprimida automáticamente
- 📍 **Multi-metro** — Soporte para múltiples propiedades, cada uno con sus equipos

## 📊 Tarifario UNE

| Rango | kWh | CUP/kWh |
|-------|-----|--------|
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

Recargo: 25% sobre kWh que excedan 500.

## 🛠️ Requisitos de desarrollo

- Flutter 3.22+
- Android SDK 34
- Java 17 (incluido en Android Studio)

## 🚀 Compilar

```bash
# Dependencias
flutter pub get

# APK debug
flutter build apk --debug

# APK release ligero (arm64)
flutter build apk --release --split-per-abi --target-platform android-arm64
```

El APK se genera en `build/app/outputs/flutter-apk/`

## 📁 Estructura

```
lib/
├── main.dart                    # App + navegación + tema
├── models.dart                  # Reading, Equipment, AppConfig, TariffConfig
├── db_service.dart              # Persistencia con Hive/IndexedDB
├── tariff_calc.dart             # Lógica de cálculo tarifas UNE
├── theme.dart                   # Tema visual (dark/light) + widgets styled
├── screens/
│   ├── calculator_screen.dart   # Calculadora de factura
│   ├── readings_screen.dart     # Registro lecturas + historial
│   ├── chart_screen.dart        # Gráficos + comparación
│   ├── equipment_screen.dart    # Gestión equipos
│   └── config_screen.dart       # Configuración general
└── widgets/
    └── confirm_dialog.dart      # Diálogo de confirmación custom
```

## 📦 Dependencias

| Paquete | Uso |
|---------|-----|
| hive_flutter | Almacenamiento local |
| image_picker | Captura de fotos |
| fl_chart | Gráficos de barras |
| intl | Formato de fechas |
| share_plus | Exportar backup |
| file_picker | Importar backup |
| path_provider | Rutas del sistema |

## 🤝 Contribuir

Ver [CONTRIBUTING.md](CONTRIBUTING.md)

## 🌐 Versión Web

Disponible como PWA en [UNE](https://github.com/YoandryF/UNE)

## 📄 Licencia

MIT License - Uso libre.
