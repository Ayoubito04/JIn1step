// Pantalla principal, con distintas secciones en pestañas.
//
// Lo que se ve en cada pestaña cambia según el rol del usuario: un candidato
// busca ofertas y sigue sus postulaciones, un reclutador gestiona las suyas.
// Este archivo es solo el ARMAZÓN (navegación entre secciones); el contenido
// de cada una debería acabar en su propio archivo a medida que crezca:
//   - Ofertas       -> screens/ofertas.dart (ya creado, vacío)
//   - Mis ofertas   -> screens/mis_ofertas.dart
//   - Mensajes      -> screens/mensajes.dart
//   - Perfil        -> screens/perfil.dart
// Aquí se dejan como widgets privados de una sola pieza, a modo de esqueleto.
//
// Diseño: Material Design 3 "a la Google" — superficies tonales (Card con
// primaryContainer / surfaceContainer), sin degradados ni desenfoques. Los
// colores nunca se escriben a mano: siempre salen de Theme.of(context).
// colorScheme, que ya deriva del azul semilla en core/app_theme.dart.
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/auth.service.dart';
import '../services/ofertas.services.dart';
import 'ofertas.dart';
import 'publicar_oferta.dart';

class Home extends StatefulWidget {
  const Home({super.key, this.ofertasService});

  /// Opcional para poder inyectar un servicio falso en los tests, igual que
  /// hace LoginScreen con AuthService. Sin esto, la pestaña Ofertas hace una
  /// llamada de red real en cuanto Home se construye (IndexedStack monta
  /// todas las pestañas de golpe): en un test sin backend, el spinner de
  /// carga gira para siempre y pumpAndSettle nunca termina.
  final OfertasService? ofertasService;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _indice = 0;

  /// Los datos del usuario ({id, nombre, apellidos, email, rol}) llegan como
  /// argumento de la ruta, puestos por login.dart / register.dart al navegar
  /// con pushNamedAndRemoveUntil('/home', ..., arguments: usuario).
  Map<String, dynamic>? _usuario;
  Rol? _rol;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // didChangeDependencies y no initState: ModalRoute.of(context) necesita
    // que el widget ya esté insertado en el árbol, y en initState todavía
    // no lo está.
    if (_usuario != null) return;

    final argumentos = ModalRoute.of(context)?.settings.arguments;

    if (argumentos is Map<String, dynamic>) {
      _usuario = argumentos;
      _rol = Rol.desdeApi(argumentos['rol'] as String);
      return;
    }

    // Se ha llegado a /home sin pasar por login (por ejemplo, tras un hot
    // restart mientras se estaba aquí). No hay usuario que mostrar, así que
    // se manda de vuelta. addPostFrameCallback evita navegar en mitad de un
    // build, que lanzaría una excepción.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      }
    });
  }

  Future<void> _cerrarSesion() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  void _irAPestana(int indice) => setState(() => _indice = indice);

  @override
  Widget build(BuildContext context) {
    // Mientras se redirige al login (caso sin argumentos) no hay nada que
    // pintar todavía.
    if (_usuario == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final usuario = _usuario!;
    final esCandidato = _rol == Rol.candidato;

    // Las secciones se arman aquí, no en el build de cada pestaña, porque
    // dependen del rol: candidato y reclutador no ven la misma segunda
    // pestaña ni el mismo contenido en Inicio.
    final secciones = <_Seccion>[
      _Seccion(
        etiqueta: 'Inicio',
        icono: Icons.home_outlined,
        iconoActivo: Icons.home,
        pagina: _InicioTab(
          usuario: usuario,
          esCandidato: esCandidato,
          onIrAPestana: _irAPestana,
        ),
      ),
      esCandidato
          // Sin "const": Ofertas recibe widget.ofertasService, que no es
          // una constante de compilación.
          ? _Seccion(
              etiqueta: 'Ofertas',
              icono: Icons.work_outline,
              iconoActivo: Icons.work,
              // Ofertas ya trae su propio Scaffold+AppBar, igual que
              // _MisOfertasTab de aquí abajo: no hace falta envolverla en
              // _Encabezado, se usa tal cual como cuerpo de la pestaña.
              pagina: Ofertas(ofertaService: widget.ofertasService),
            )
          : const _Seccion(
              etiqueta: 'Mis ofertas',
              icono: Icons.business_center_outlined,
              iconoActivo: Icons.business_center,
              pagina: _MisOfertasTab(),
            ),
      const _Seccion(
        etiqueta: 'Mensajes',
        icono: Icons.chat_bubble_outline,
        iconoActivo: Icons.chat_bubble,
        pagina: _MensajesTab(),
      ),
      _Seccion(
        etiqueta: 'Perfil',
        icono: Icons.person_outline,
        iconoActivo: Icons.person,
        pagina: _PerfilTab(
          usuario: usuario,
          rol: _rol!,
          onCerrarSesion: _cerrarSesion,
        ),
      ),
    ];

    return Scaffold(
      // IndexedStack y no un simple "secciones[_indice].pagina" en el body:
      // con IndexedStack las cuatro pestañas se construyen una vez y se
      // mantienen vivas de fondo, así que el scroll o el texto escrito en
      // una no se pierde al pasar a otra y volver.
      body: IndexedStack(
        index: _indice,
        children: [for (final s in secciones) s.pagina],
      ),
      // El estilo de la barra (colores, tipografía) sale de
      // navigationBarTheme en core/app_theme.dart.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: _irAPestana,
        destinations: [
          for (final s in secciones)
            NavigationDestination(
              icon: Icon(s.icono),
              selectedIcon: Icon(s.iconoActivo),
              label: s.etiqueta,
            ),
        ],
      ),
    );
  }
}

/// Datos de una pestaña: qué icono lleva y qué pinta.
class _Seccion {
  const _Seccion({
    required this.etiqueta,
    required this.icono,
    required this.iconoActivo,
    required this.pagina,
  });

  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pagina;
}

// ─── Cabecera compartida ────────────────────────────────────────────────

/// Título grande arriba de una pestaña, como el "Hola" de Gmail o el
/// encabezado de Google One: texto sobre el fondo normal, sin caja de color
/// detrás. Es la alternativa Material 3 a la cabecera con degradado.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
      ),
    );
  }
}

// ─── Inicio ─────────────────────────────────────────────────────────────

/// Resumen al entrar. Candidatos y reclutadores ven tarjetas distintas.
///
/// TODO: sustituir los valores fijos ("0") por datos reales:
///   - candidato: GET /postulaciones/mias (cuántas lleva) y
///     GET /preferencias-autopilot (si el autopiloto está activo).
///   - reclutador: GET /ofertas/mias (cuántas tiene abiertas).
class _InicioTab extends StatelessWidget {
  const _InicioTab({
    required this.usuario,
    required this.esCandidato,
    required this.onIrAPestana,
  });

  final Map<String, dynamic> usuario;
  final bool esCandidato;

  /// Las acciones rápidas saltan a otra pestaña del NavigationBar en vez de
  /// duplicar su contenido aquí.
  final void Function(int indice) onIrAPestana;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: esquema.primaryContainer,
                child: Text(
                  (usuario['nombre'] as String).substring(0, 1).toUpperCase(),
                  style: TextStyle(color: esquema.onPrimaryContainer, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hola, ${usuario['nombre']}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // TODO: notificaciones reales. Por ahora solo visual.
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none),
                style: IconButton.styleFrom(
                  backgroundColor: esquema.surfaceContainerHighest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            esCandidato
                ? 'Esto es lo que está pasando con tu búsqueda'
                : 'Esto es lo que está pasando con tus ofertas',
            style: TextStyle(color: esquema.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          // Tarjeta "hero" tonal: fondo primaryContainer, el patrón de
          // Material You para destacar el dato más importante de la
          // pantalla (aquí, sin el degradado ni el cristal de antes).
          Card(
            color: esquema.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esCandidato ? 'Postulaciones activas' : 'Ofertas publicadas',
                    style: TextStyle(color: esquema.onPrimaryContainer.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '0',
                    style: TextStyle(
                      color: esquema.onPrimaryContainer,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Accesos rápidos, como "Buscar / Crear / Compartir" en la
          // pantalla principal de Google Fotos.
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: esCandidato
                    ? [
                        QuickAction(icono: Icons.search, etiqueta: 'Ofertas', onTap: () => onIrAPestana(1)),
                        QuickAction(icono: Icons.smart_toy_outlined, etiqueta: 'Autopiloto', onTap: () => onIrAPestana(3)),
                        QuickAction(icono: Icons.chat_bubble_outline, etiqueta: 'Mensajes', onTap: () => onIrAPestana(2)),
                        QuickAction(icono: Icons.person_outline, etiqueta: 'Perfil', onTap: () => onIrAPestana(3)),
                      ]
                    : [
                        QuickAction(icono: Icons.add_business_outlined, etiqueta: 'Publicar', onTap: () => onIrAPestana(1)),
                        QuickAction(icono: Icons.groups_outlined, etiqueta: 'Candidatos', onTap: () => onIrAPestana(1)),
                        QuickAction(icono: Icons.chat_bubble_outline, etiqueta: 'Mensajes', onTap: () => onIrAPestana(2)),
                        QuickAction(icono: Icons.person_outline, etiqueta: 'Perfil', onTap: () => onIrAPestana(3)),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _tarjetaResumen(
                  context,
                  icono: esCandidato ? Icons.send_outlined : Icons.work_outline,
                  titulo: esCandidato ? 'Postulaciones' : 'Ofertas abiertas',
                  valor: '0',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tarjetaResumen(
                  context,
                  icono: esCandidato ? Icons.smart_toy_outlined : Icons.groups_outlined,
                  titulo: esCandidato ? 'Autopiloto' : 'Candidatos',
                  valor: esCandidato ? 'Inactivo' : '0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaResumen(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String valor,
  }) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: esquema.primary),
            const SizedBox(height: 8),
            Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: esquema.onSurface)),
            Text(titulo, style: TextStyle(fontSize: 12, color: esquema.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}


// ─── Mis ofertas (reclutador) ───────────────────────────────────────────

/// TODO: mover a screens/mis_ofertas.dart. Backend: GET /ofertas/mias,
/// POST /ofertas para publicar una nueva.
class _MisOfertasTab extends StatelessWidget {
  const _MisOfertasTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const Column(
        children: [
          _Encabezado(titulo: 'Mis ofertas'),
          Expanded(
            child: _MarcadorDeSeccion(
              icono: Icons.business_center_outlined,
              texto: 'Aquí irán las ofertas que has publicado',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // El formulario devuelve true si se publicó de verdad. Por ahora
          // solo se avisa con un SnackBar: la lista de "Mis ofertas" sigue
          // siendo un marcador, todavía no lista nada, así que no hay nada
          // que refrescar aquí de momento.
          final publicada = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => const PublicarOferta()),
          );

          if (publicada == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Oferta publicada')),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Publicar oferta'),
      ),
    );
  }
}

// ─── Mensajes ───────────────────────────────────────────────────────────

/// TODO: mover a screens/mensajes.dart. Backend: GET /conversaciones para
/// la lista de chats, GET /conversaciones/:id/mensajes para abrir uno.
class _MensajesTab extends StatelessWidget {
  const _MensajesTab();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _Encabezado(titulo: 'Mensajes'),
        Expanded(
          child: _MarcadorDeSeccion(
            icono: Icons.chat_bubble_outline,
            texto: 'Aquí irán tus conversaciones',
          ),
        ),
      ],
    );
  }
}

// ─── Perfil ─────────────────────────────────────────────────────────────

/// TODO: mover a screens/perfil.dart.
class _PerfilTab extends StatelessWidget {
  const _PerfilTab({
    required this.usuario,
    required this.rol,
    required this.onCerrarSesion,
  });

  final Map<String, dynamic> usuario;
  final Rol rol;
  final Future<void> Function() onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: esquema.primaryContainer,
                  child: Text(
                    (usuario['nombre'] as String).substring(0, 1).toUpperCase(),
                    style: TextStyle(fontSize: 28, color: esquema.onPrimaryContainer, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${usuario['nombre']} ${usuario['apellidos']}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  usuario['email'] as String,
                  style: TextStyle(color: esquema.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Chip(label: Text(rol.etiqueta)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _opcionPerfil(
            context,
            icono: Icons.edit_outlined,
            titulo: 'Editar perfil',
            onTap: () {
              // TODO: llevar a la pantalla de editar perfil.
              // Candidato: PATCH /perfil-candidato/mio (ubicación,
              // disponibilidad). Reclutador: aún no tiene endpoint propio.
            },
          ),
          if (rol == Rol.candidato)
            _opcionPerfil(
              context,
              icono: Icons.smart_toy_outlined,
              titulo: 'Autopiloto de postulaciones',
              onTap: () {
                // TODO: pantalla de preferencias del autopiloto
                // (GET/PATCH /preferencias-autopilot) y suscripción
                // (GET/POST /suscripciones), que es lo que lo desbloquea.
              },
            ),
          const Divider(height: 32),
          Card(
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              leading: Icon(Icons.logout, color: esquema.error),
              title: Text('Cerrar sesión', style: TextStyle(color: esquema.error, fontWeight: FontWeight.w600)),
              onTap: onCerrarSesion,
            ),
          ),
        ],
      ),
    );
  }

  Widget _opcionPerfil(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required VoidCallback onTap,
  }) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: CircleAvatar(
          backgroundColor: esquema.primaryContainer,
          child: Icon(icono, color: esquema.onPrimaryContainer),
        ),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.chevron_right, color: esquema.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}

// ─── Ayuda compartida ───────────────────────────────────────────────────

/// Marcador visual para una sección todavía sin construir. Solo para no
/// dejar el esqueleto con pantallas en blanco mientras se van rellenando.
class _MarcadorDeSeccion extends StatelessWidget {
  const _MarcadorDeSeccion({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 48, color: color),
          const SizedBox(height: 12),
          Text(texto, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
