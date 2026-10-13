import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/app_theme.dart';
import 'firebase_options.dart';
import 'screens/login.dart';
import 'screens/register.dart';
import 'screens/home.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FlutterFire se ha configurado para Android. Evita inicializarlo en web y
  // escritorio hasta que esas plataformas también se registren en Firebase.
  if (defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jin1step',
      debugShowCheckedModeBanner: false,
      // Todo el tema (colores, tarjetas, botones) vive en core/app_theme.dart
      theme: construirTemaApp(),
      builder: (context, child) => AnimatedLinesBackground(
        child: child ?? const SizedBox.shrink(),
      ),
      // Cada pantalla a la que se navegue con pushNamed tiene que estar aquí.
      // Si falta, la app falla con "Could not find a generator for route".
      //
      // '/' apunta también al login: en Flutter Web, si la pestaña del
      // navegador está en la URL raíz (localhost:PUERTO/, sin "/login"), la
      // app pide la ruta "/" en vez de initialRoute. Sin esta entrada, eso
      // revienta con "Could not find a generator for route RouteSettings(/)".
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const Home(),
      },
      // Red de seguridad: cualquier ruta que no esté en el mapa de arriba
      // (una futura, una mal escrita, una que quede de una versión vieja
      // en el historial del navegador) cae aquí en vez de tirar la app.
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}
