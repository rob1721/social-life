# Nuestro Calendario

Red social privada centrada en un calendario: comparte actividades, planes, fotos
y recuerdos solo con las personas que invitas (pareja, familia, amigos...).

- **Front:** Flutter (mobile primero; la base ya compila para web).
- **Back:** Firebase (Auth con Google, Firestore, Storage).

La arquitectura, el esquema de datos y las decisiones de diseño están en
[`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md).

## Estructura

```
lib/
  main.dart                 # Inicializa Firebase, fechas en español y Riverpod
  app.dart                  # Rutas (go_router) + redirección según sesión
  firebase_options.dart     # PROVISIONAL: lo genera `flutterfire configure`
  providers.dart            # Providers de Riverpod (sesión, redes, eventos, colores)
  core/calendar_window.dart # Ventana de -2 / +3 semanas del calendario
  models/                   # AppUser, Circle, Invite, CalendarEvent, EventPost, EventUserState
  data/                     # AuthService y repositorios de Firestore/Storage
  features/                 # Pantallas: login, inicio, día, evento, perfil, redes
  widgets/common.dart       # Avatar, post-it, selector de color
firestore.rules             # Reglas de seguridad (quién ve / edita qué)
storage.rules               # Reglas para fotos
rules_test/                 # Tests de las reglas contra el emulador
```

## Configurar Firebase (una sola vez)

1. Crea un proyecto en <https://console.firebase.google.com>.
2. **Authentication → Método de acceso →** habilita **Google**.
3. Crea **Firestore Database** y **Storage**.
4. Instala las herramientas y conecta la app:

   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   flutterfire configure --platforms=android,ios,web
   ```

   Esto reemplaza `lib/firebase_options.dart` y agrega
   `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist`.

5. **Android:** registra las huellas SHA-1 y SHA-256 de tu llave de firma en
   *Configuración del proyecto → Tus apps → Android* y vuelve a descargar
   `google-services.json` (sin esto, Google Sign-In falla). Para la llave de debug:

   ```bash
   cd android && ./gradlew signingReport
   ```

6. **iOS:** en `ios/Runner/Info.plist` agrega `GIDClientID` (el `CLIENT_ID` de
   `GoogleService-Info.plist`) y un `CFBundleURLTypes` con el
   `REVERSED_CLIENT_ID` como esquema de URL.

7. Publica las reglas:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

Si ejecutas la app antes de configurar Firebase, verás una pantalla indicando
que falta este paso.

## Ejecutar

```bash
flutter pub get
flutter run                # dispositivo/emulador conectado
flutter run -d chrome      # web
```

## Tests

```bash
flutter analyze
flutter test                     # lógica del calendario y modelos

cd rules_test && npm install && npm test   # reglas de Firestore (requiere Java)
```
