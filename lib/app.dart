import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/calendar_window.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/circles/circles_screen.dart';
import 'features/day/day_screen.dart';
import 'features/events/event_form_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/user_profile_screen.dart';
import 'providers.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
  static const profile = '/profile';
  static const circles = '/circles';

  static String day(DateTime d) => '/day/${dayKey(d)}';
  static String newEvent(DateTime d) => '/events/new?date=${dayKey(d)}';
  static String editEvent(String circleId, String eventId) =>
      '/events/$circleId/$eventId/edit';
  static String user(String uid) => '/users/$uid';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final location = state.matchedLocation;
      if (auth.isLoading && !auth.hasValue) {
        return location == Routes.splash ? null : Routes.splash;
      }
      final signedIn = auth.value != null;
      if (!signedIn) return location == Routes.login ? null : Routes.login;
      if (location == Routes.login || location == Routes.splash) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => const SignInScreen()),
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(path: Routes.circles, builder: (_, _) => const CirclesScreen()),
      GoRoute(
        path: '/users/:uid',
        builder: (_, s) => UserProfileScreen(uid: s.pathParameters['uid']!),
      ),
      GoRoute(
        path: '/day/:date',
        builder: (_, s) => DayScreen(
          day:
              parseDayKey(s.pathParameters['date']!) ??
              dateOnly(DateTime.now()),
        ),
      ),
      GoRoute(
        path: '/events/new',
        builder: (_, s) => EventFormScreen(
          initialDay: parseDayKey(s.uri.queryParameters['date'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/events/:circleId/:eventId/edit',
        builder: (_, s) => EventFormScreen(
          circleId: s.pathParameters['circleId'],
          eventId: s.pathParameters['eventId'],
        ),
      ),
    ],
  );
});

class NuestroCalendarioApp extends ConsumerWidget {
  const NuestroCalendarioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Nuestro Calendario',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6D5BD0),
        useMaterial3: true,
      ),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
