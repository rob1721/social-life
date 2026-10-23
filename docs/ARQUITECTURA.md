# Arquitectura y esquema de datos

## Conceptos

| Concepto | Qué es |
|---|---|
| **Usuario** | Cuenta de Google autenticada en Firebase. |
| **Red (círculo)** | Grupo privado: pareja, familia, amigos, etc. Cada usuario tiene una red personal ("Mi red") creada automáticamente. |
| **Invitación** | Se invita por Gmail. La persona ve la invitación en su muro y la acepta o rechaza. |
| **Evento** | Algo en el calendario (cine, festival, vacaciones...). Pertenece a una red y lo ven todos sus miembros. |
| **Post** | Material dentro de un evento: comentario/recuerdo o foto. |
| **Estado personal del evento** | Privado de cada usuario: cuándo lo vio (para notificaciones) y si dejó de recordarlo. |

## Flujo de sesión

1. `SignInScreen` → `AuthService.signInWithGoogle()`.
   - Mobile: `google_sign_in` (selector nativo de cuentas) → `idToken` → `FirebaseAuth.signInWithCredential`.
   - Web: `FirebaseAuth.signInWithPopup(GoogleAuthProvider())`.
2. Firebase Auth persiste la sesión, así que el usuario queda recordado entre aperturas.
3. `authStateProvider` escucha la sesión y, antes de dejar pasar, ejecuta
   `UserRepository.ensureProfile()`: en el primer ingreso crea `users/{uid}` y la red
   personal `circles/{uid}`.
4. `go_router` redirige a `/login` o `/` según haya sesión.

## Esquema de Firestore

```
users/{uid}
  uid, email, googleName, googlePhotoUrl     ← vienen de Google, no editables
  nickname, showNickname, avatarUrl, colorValue
  createdAt, updatedAt
  └─ eventStates/{circleId}_{eventId}        ← privado del usuario
       seenAt, hidden

circles/{circleId}                           ← circleId == uid para la red personal
  name, ownerId, memberIds[], kind (personal|couple|family|friends|other), createdAt
  └─ events/{eventId}
       circleId, ownerId, title, description, location
       startAt, endAt, allDay
       participantIds[], declinedIds[]
       lastActivityAt, lastActivityBy        ← para notificaciones "no vistas"
       createdAt, updatedAt
       └─ posts/{postId}
            authorId, type (note|photo), text, mediaUrls[], createdAt, updatedAt

invites/{circleId}_{email}
  circleId, circleName, email, invitedBy, invitedByName,
  status (pending|accepted|declined), createdAt, respondedAt
```

### Storage

```
users/{uid}/avatar.jpg
circles/{circleId}/events/{eventId}/{uid}/{timestamp}.jpg
```

## Reglas clave (`firestore.rules`)

- Solo los miembros de una red pueden ver la red, sus eventos y sus posts.
- Solo el creador de un evento puede editarlo o borrarlo.
- Cualquier miembro puede cambiar **solo su propia** participación (participo / no participo),
  en eventos pasados o futuros.
- Solo el autor de un post puede editarlo o borrarlo.
- `googleName` y `email` deben coincidir con el token de Google: un apodo nunca puede
  suplantar el nombre real, y el perfil de otra persona siempre muestra ambos.
- Para unirse a una red se necesita una invitación pendiente dirigida a tu correo.
- La red personal no se puede borrar.

Todo esto está cubierto por `rules_test/firestore.test.js`.

## Decisiones de diseño

- **Eventos como subcolección de la red.** Así las reglas validan la membresía desde la ruta
  (`circles/{circleId}/...`), lo que es confiable también en consultas. La app hace una
  consulta por red y combina los resultados (`EventRepository.watchEventsInRange`).
- **Ventana del calendario.** `CalendarWindow` muestra semanas completas de lunes a domingo:
  2 semanas atrás, la actual y 3 adelante (6 filas). Las flechas la desplazan de a 3 semanas,
  por ejemplo para llegar al 22/12/2026 estando en octubre.
- **Eventos de varios días.** Se consulta por `startAt` con un margen de 31 días hacia atrás
  y se filtra la superposición en el cliente; por eso un evento dura como máximo 31 días.
- **Notificaciones sin backend.** Cada evento guarda `lastActivityAt/By`; un evento es "no visto"
  si otra persona tuvo actividad después de mi `seenAt`. Abrir el día lo marca como visto.
- **"Dejar de recordar".** Es una preferencia personal (`eventStates.hidden`); el evento sigue
  existiendo para los demás.
- **Colores.** Cada usuario elige el color de sus post-its (`colorValue`). Además puedo
  asignar localmente otro color a cualquier persona; se guarda en `shared_preferences`
  y solo afecta a mi dispositivo.
- **Estado:** Riverpod 3 (sin generación de código). **Rutas:** go_router.

## Próximos pasos sugeridos

1. Wireframes / mockups de las pantallas antes de trabajar la UI definitiva.
2. Widget de escritorio (Android/iOS) con el calendario, usando `home_widget` y un
   resumen de eventos guardado por la app.
3. Notificaciones push (Cloud Functions + FCM) al crear eventos o subir fotos.
4. Cloud Function para borrar posts y fotos cuando se elimina un evento.
5. Miniaturas de fotos en los post-its del calendario.
6. Pantalla para ver/restaurar eventos que dejaste de recordar.
