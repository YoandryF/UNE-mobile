# Contribuir a UNE Mobile

¡Gracias por tu interés en contribuir!

## Cómo contribuir

1. **Fork** el repositorio
2. Crea un **branch** desde `main`: `git checkout -b feature/mi-mejora`
3. Realiza tus cambios
4. Verifica que compile: `flutter analyze && flutter build apk --debug`
5. **Commit** con mensaje descriptivo
6. **Push** a tu fork
7. Abre un **Pull Request** hacia `main`

## Reglas

- Los PRs requieren aprobación del mantenedor antes de merge
- No se puede pushear directamente a `main`
- Usar Flutter 3.22+ compatible (no usar APIs de versiones superiores)
- Mantener compatibilidad con Android SDK 34
- No agregar dependencias innecesarias

## Convenciones

- `feat:` nueva funcionalidad
- `fix:` corrección de bug
- `docs:` documentación
- `style:` estilos/UI
- `refactor:` refactorización

## Ideas bienvenidas

- Widgets para consumo en home screen
- Notificaciones locales al superar umbral
- Modo offline mejorado
- Soporte para tarifas comerciales
- Gráficos adicionales
- Tests unitarios

## Reporte de bugs

Abre un Issue con:
- Versión de Android
- Modelo del dispositivo
- Pasos para reproducir
- Screenshots si aplica
