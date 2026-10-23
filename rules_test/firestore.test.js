import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayRemove,
  arrayUnion,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const ANA = { uid: 'ana', email: 'ana@gmail.com', name: 'Ana Pérez' };
const BEN = { uid: 'ben', email: 'ben@gmail.com', name: 'Ben Soto' };
const EVA = { uid: 'eva', email: 'eva@gmail.com', name: 'Eva Ríos' };

let env;

const db = (u) =>
  env.authenticatedContext(u.uid, { email: u.email, name: u.name }).firestore();

const event = (ownerId, extra = {}) => ({
  circleId: 'pareja',
  ownerId,
  title: 'Cine',
  startAt: Timestamp.fromDate(new Date('2026-12-22T20:00:00')),
  endAt: Timestamp.fromDate(new Date('2026-12-22T22:00:00')),
  participantIds: [ownerId],
  declinedIds: [],
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-nuestro-calendario',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    await setDoc(doc(admin, 'circles/pareja'), {
      name: 'Pareja',
      ownerId: 'ana',
      memberIds: ['ana', 'ben'],
      kind: 'couple',
    });
    await setDoc(doc(admin, 'circles/pareja/events/e1'), event('ben'));
  });
});

describe('usuarios', () => {
  test('crea su perfil con datos reales de Google', async () => {
    await assertSucceeds(
      setDoc(doc(db(ANA), 'users/ana'), {
        uid: 'ana',
        email: 'ana@gmail.com',
        googleName: 'Ana Pérez',
        nickname: null,
      }),
    );
  });

  test('no puede suplantar el nombre de Google', async () => {
    await assertFails(
      setDoc(doc(db(ANA), 'users/ana'), {
        uid: 'ana',
        email: 'ana@gmail.com',
        googleName: 'Otra Persona',
      }),
    );
  });

  test('puede cambiar su apodo pero no su email', async () => {
    const anaDb = db(ANA);
    await setDoc(doc(anaDb, 'users/ana'), {
      uid: 'ana',
      email: 'ana@gmail.com',
      googleName: 'Ana Pérez',
    });
    await assertSucceeds(updateDoc(doc(anaDb, 'users/ana'), { nickname: 'Anita' }));
    await assertFails(updateDoc(doc(anaDb, 'users/ana'), { email: 'x@gmail.com' }));
  });

  test('no puede editar el perfil de otro', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'users/ben'), { uid: 'ben', email: 'ben@gmail.com' }),
    );
    await assertFails(updateDoc(doc(db(ANA), 'users/ben'), { nickname: 'troll' }));
  });
});

describe('círculos y eventos', () => {
  test('un no miembro no ve la red ni sus eventos', async () => {
    await assertFails(getDoc(doc(db(EVA), 'circles/pareja')));
    await assertFails(getDocs(collection(db(EVA), 'circles/pareja/events')));
  });

  test('los miembros listan sus redes y eventos', async () => {
    await assertSucceeds(
      getDocs(query(collection(db(ANA), 'circles'), where('memberIds', 'array-contains', 'ana'))),
    );
    await assertSucceeds(getDocs(collection(db(ANA), 'circles/pareja/events')));
  });

  test('un miembro crea eventos propios pero no a nombre de otro', async () => {
    await assertSucceeds(setDoc(doc(db(ANA), 'circles/pareja/events/e2'), event('ana')));
    await assertFails(setDoc(doc(db(ANA), 'circles/pareja/events/e3'), event('ben')));
  });

  test('no puedo editar ni borrar el evento de otro', async () => {
    await assertFails(updateDoc(doc(db(ANA), 'circles/pareja/events/e1'), { title: 'Hackeado' }));
  });

  test('sí puedo cambiar MI participación en el evento de otro', async () => {
    await assertSucceeds(
      updateDoc(doc(db(ANA), 'circles/pareja/events/e1'), {
        participantIds: arrayRemove('ana'),
        declinedIds: arrayUnion('ana'),
      }),
    );
  });

  test('no puedo sacar a otra persona de un evento', async () => {
    await assertFails(
      updateDoc(doc(db(ANA), 'circles/pareja/events/e1'), {
        participantIds: arrayRemove('ben'),
      }),
    );
  });

  test('solo el autor modifica su post', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'circles/pareja/events/e1/posts/p1'), {
        authorId: 'ben',
        text: 'Qué buena peli',
      }),
    );
    await assertFails(
      updateDoc(doc(db(ANA), 'circles/pareja/events/e1/posts/p1'), { text: 'editado' }),
    );
    await assertSucceeds(
      updateDoc(doc(db(BEN), 'circles/pareja/events/e1/posts/p1'), { text: 'editado' }),
    );
  });
});

describe('invitaciones', () => {
  test('no puedo unirme a una red sin invitación', async () => {
    await assertFails(
      updateDoc(doc(db(EVA), 'circles/pareja'), { memberIds: arrayUnion('eva') }),
    );
  });

  test('flujo completo: invitar, ver invitación y aceptar', async () => {
    const inviteId = 'pareja_eva@gmail.com';
    await assertSucceeds(
      setDoc(doc(db(ANA), `invites/${inviteId}`), {
        circleId: 'pareja',
        circleName: 'Pareja',
        email: 'eva@gmail.com',
        invitedBy: 'ana',
        invitedByName: 'Ana',
        status: 'pending',
      }),
    );

    const evaDb = db(EVA);
    const pending = await assertSucceeds(
      getDocs(
        query(
          collection(evaDb, 'invites'),
          where('email', '==', 'eva@gmail.com'),
          where('status', '==', 'pending'),
        ),
      ),
    );
    if (pending.size !== 1) throw new Error('esperaba 1 invitación');

    const batch = writeBatch(evaDb);
    batch.update(doc(evaDb, `invites/${inviteId}`), { status: 'accepted' });
    batch.update(doc(evaDb, 'circles/pareja'), { memberIds: arrayUnion('eva') });
    await assertSucceeds(batch.commit());

    await assertSucceeds(getDocs(collection(evaDb, 'circles/pareja/events')));
  });

  test('no puedo invitar a una red de la que no soy miembro', async () => {
    await assertFails(
      setDoc(doc(db(EVA), 'invites/pareja_eva@gmail.com'), {
        circleId: 'pareja',
        email: 'eva@gmail.com',
        invitedBy: 'eva',
        status: 'pending',
      }),
    );
  });
});
