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
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/auth.service.dart';
import '../services/candidato.service.dart';
import '../services/chat.service.dart';
import '../services/ofertas.services.dart';
import 'autopilot.dart';
import 'mis_cvs.dart';
import 'mensajes.dart';
import 'mis_ofertas.dart';
import 'mis_postulaciones.dart';
import 'ofertas.dart';

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
  int _versionMensajes = 0;
  final _candidatoService = CandidatoService();
  List<Map<String, dynamic>> _entrevistas = [];
  Timer? _temporizadorNotificaciones;
  bool _notificacionesIniciadas = false;
  bool _notificacionesCargando = true;
  bool _primeraCargaEntrevistas = true;

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
      _iniciarActualizacionEntrevistas();
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

  void _iniciarActualizacionEntrevistas() {
    if (_notificacionesIniciadas || _rol != Rol.candidato) return;
    _notificacionesIniciadas = true;
    unawaited(_cargarEntrevistas());
    _temporizadorNotificaciones = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(_cargarEntrevistas()),
    );
  }

  Future<void> _cargarEntrevistas() async {
    try {
      final postulaciones = await _candidatoService.listarPostulaciones();
      final entrevistas = postulaciones
          .where((postulacion) => postulacion['estado'] == 'ENTREVISTA')
          .toList();
      final idsAnteriores = _entrevistas
          .map((postulacion) => postulacion['id'])
          .toSet();
      final hayNuevaEntrevista =
          !_primeraCargaEntrevistas &&
          entrevistas.any(
            (postulacion) => !idsAnteriores.contains(postulacion['id']),
          );

      if (!mounted) return;
      setState(() {
        _entrevistas = entrevistas;
        _notificacionesCargando = false;
      });
      _primeraCargaEntrevistas = false;

      if (hayNuevaEntrevista) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Te han seleccionado para una entrevista.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _notificacionesCargando = false);
      _primeraCargaEntrevistas = false;
    }
  }

  void _mostrarNotificaciones() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final esquema = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notificaciones',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: () => unawaited(_cargarEntrevistas()),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_notificacionesCargando && _entrevistas.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_entrevistas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 42,
                            color: esquema.primary,
                          ),
                          const SizedBox(height: 10),
                          const Text('Todavía no tienes entrevistas.'),
                        ],
                      ),
                    ),
                  )
                else ...[
                  for (final postulacion in _entrevistas)
                    _NotificacionEntrevista(
                      postulacion: postulacion,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MisPostulacionesPage(),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _temporizadorNotificaciones?.cancel();
    super.dispose();
  }

  Future<void> _cerrarSesion() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
  }

  void _irAPestana(int indice) => setState(() {
    _indice = indice;
    if (indice == (_rol == Rol.candidato ? 3 : 2)) _versionMensajes++;
  });

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
      if (esCandidato) ...[
        _Seccion(
          etiqueta: 'Inicio',
          icono: Icons.home_outlined,
          iconoActivo: Icons.home,
          pagina: _InicioCandidatoTab(
            usuario: usuario,
            onIrAPestana: _irAPestana,
            onVerCandidaturas: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MisPostulacionesPage()),
            ),
          ),
        ),
        _Seccion(
          etiqueta: 'Ofertas',
          icono: Icons.work_outline,
          iconoActivo: Icons.work,
          pagina: Ofertas(ofertaService: widget.ofertasService),
        ),
        _Seccion(
          etiqueta: 'Autopiloto',
          icono: Icons.auto_awesome_outlined,
          iconoActivo: Icons.auto_awesome,
          pagina: const AutopilotPage(),
        ),
        _Seccion(
          etiqueta: 'Chat',
          icono: Icons.chat_bubble_outline,
          iconoActivo: Icons.chat_bubble,
          pagina: MensajesPage(
            key: ValueKey(_versionMensajes),
            usuarioId: usuario['id'] as String,
          ),
        ),
        _Seccion(
          etiqueta: 'Mi CV',
          icono: Icons.person_outline,
          iconoActivo: Icons.person,
          pagina: const MisCvsPage(seleccionable: false),
        ),
      ] else ...[
        _Seccion(
          etiqueta: 'Inicio',
          icono: Icons.home_outlined,
          iconoActivo: Icons.home,
          pagina: _InicioTab(
            usuario: usuario,
            esCandidato: false,
            onIrAPestana: _irAPestana,
            entrevistas: _entrevistas,
            onMostrarNotificaciones: _mostrarNotificaciones,
          ),
        ),
        _Seccion(
          etiqueta: 'Mis ofertas',
          icono: Icons.business_center_outlined,
          iconoActivo: Icons.business_center,
          pagina: MisOfertasPage(usuarioId: usuario['id'] as String),
        ),
        _Seccion(
          etiqueta: 'Mensajes',
          icono: Icons.chat_bubble_outline,
          iconoActivo: Icons.chat_bubble,
          pagina: MensajesPage(
            key: ValueKey(_versionMensajes),
            usuarioId: usuario['id'] as String,
          ),
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
      ],
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
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
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
class _NotificacionEntrevista extends StatelessWidget {
  const _NotificacionEntrevista({
    required this.postulacion,
    required this.onTap,
  });

  final Map<String, dynamic> postulacion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oferta = postulacion['oferta'] as Map<String, dynamic>? ?? {};
    final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.event_available_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          oferta['titulo'] as String? ?? 'Entrevista',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${empresa['nombre'] ?? 'El reclutador'} te ha seleccionado para una entrevista. Contacta por el chat para acordar fecha y hora.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

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

/// Resumen del candidato, construido con los datos del backend y con la
/// composición visual de la referencia PNG de Inicio.
class _InicioCandidatoTab extends StatefulWidget {
  const _InicioCandidatoTab({
    required this.usuario,
    required this.onIrAPestana,
    required this.onVerCandidaturas,
  });

  final Map<String, dynamic> usuario;
  final ValueChanged<int> onIrAPestana;
  final VoidCallback onVerCandidaturas;

  @override
  State<_InicioCandidatoTab> createState() => _InicioCandidatoTabState();
}

class _InicioCandidatoTabState extends State<_InicioCandidatoTab> {
  final _candidato = CandidatoService();
  final _ofertas = OfertasService();
  final _chat = ChatService();
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _postulaciones = [];
  List<Map<String, dynamic>> _ofertasDisponibles = [];
  List<Map<String, dynamic>> _conversaciones = [];
  Map<String, dynamic> _preferencias = {};
  Set<String> _habilidades = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final datos = await Future.wait<Object?>([
        _candidato.listarPostulaciones(),
        _candidato.obtenerPreferenciasAutopilot(),
        _ofertas.getAllOfertas(),
        _chat.listarConversaciones(),
        _candidato.listarCvs(),
      ]);
      final cvs = datos[4] as List<Map<String, dynamic>>;
      Set<String> habilidades = {};
      if (cvs.isNotEmpty && cvs.first['id'] is String) {
        final lista = await _candidato.listarHabilidadesCv(
          cvs.first['id'] as String,
        );
        habilidades = lista
            .map(
              (item) => (item['habilidad'] as Map<String, dynamic>?)?['nombre'],
            )
            .whereType<String>()
            .map((nombre) => nombre.trim().toLowerCase())
            .toSet();
      }
      if (!mounted) return;
      setState(() {
        _postulaciones = datos[0] as List<Map<String, dynamic>>;
        _preferencias = datos[1] as Map<String, dynamic>;
        _ofertasDisponibles = datos[2] as List<Map<String, dynamic>>;
        _conversaciones = datos[3] as List<Map<String, dynamic>>;
        _habilidades = habilidades;
        _cargando = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error.toString();
          _cargando = false;
        });
    }
  }

  bool _esHoy(Object? fecha) {
    if (fecha is! String) return false;
    final date = DateTime.tryParse(fecha)?.toLocal();
    final now = DateTime.now();
    return date != null &&
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  int? _match(Map<String, dynamic> oferta) {
    if (_habilidades.isEmpty) return null;
    final requisitos = (oferta['requisitos'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    final obligatorias = requisitos
        .where((r) => r['obligatorio'] != false)
        .toList();
    final deseables = requisitos
        .where((r) => r['obligatorio'] == false)
        .toList();
    if (obligatorias.isEmpty && deseables.isEmpty) return null;
    int cuenta(List<Map<String, dynamic>> items) => items.where((r) {
      final nombre =
          (r['habilidad'] as Map<String, dynamic>?)?['nombre'] as String?;
      return nombre != null &&
          _habilidades.contains(nombre.trim().toLowerCase());
    }).length;
    final ratioO = obligatorias.isEmpty
        ? 1.0
        : cuenta(obligatorias) / obligatorias.length;
    final ratioD = deseables.isEmpty
        ? 1.0
        : cuenta(deseables) / deseables.length;
    return (ratioO * 70 + ratioD * 30).round();
  }

  List<({Map<String, dynamic> oferta, int score})> get _mejores {
    final items = <({Map<String, dynamic> oferta, int score})>[];
    for (final oferta in _ofertasDisponibles) {
      final score = _match(oferta);
      if (score != null) items.add((oferta: oferta, score: score));
    }
    items.sort((a, b) => b.score.compareTo(a.score));
    return items.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudo cargar tu resumen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: esquema.onSurfaceVariant),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _cargando = true;
                    _error = null;
                  });
                  _cargar();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final entrevistas = _postulaciones
        .where((p) => p['estado'] == 'ENTREVISTA')
        .length;
    final scores = _postulaciones
        .map((p) => p['matchScore'])
        .whereType<num>()
        .toList();
    final media = scores.isEmpty
        ? null
        : (scores.fold<double>(0, (sum, score) => sum + score) / scores.length)
              .round();
    final hoy = _postulaciones
        .where(
          (p) => p['postuladoPorIa'] == true && _esHoy(p['fechaPostulacion']),
        )
        .length;
    final limite = (_preferencias['maxPorDia'] as num?)?.toInt() ?? 5;
    final minimo = (_preferencias['scoreMinimo'] as num?)?.toInt() ?? 70;
    final activo = _preferencias['activo'] == true;
    final matches = _mejores;
    final inicial = (widget.usuario['nombre'] as String? ?? 'U').trim();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, .38, 1],
          colors: [Color(0xFFE9E4FA), Color(0xFFF6F4FD), AppColors.white],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hola de nuevo',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Tu resumen',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    inicial.isEmpty
                        ? 'U'
                        : inicial.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activo ? 'Autopiloto activo' : 'Autopiloto inactivo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Mín. ' + minimo.toString() + '%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hoy.toString() +
                        ' de ' +
                        limite.toString() +
                        ' postulaciones enviadas hoy',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: limite == 0 ? 0 : (hoy / limite).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: Colors.white.withValues(alpha: .28),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _metrica(
                    context,
                    _postulaciones.length.toString(),
                    'Candidaturas',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metrica(
                    context,
                    entrevistas.toString(),
                    'Entrevistas',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metrica(
                    context,
                    media == null ? '—' : media.toString() + '%',
                    'Match medio',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mejores matches',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onIrAPestana(1),
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            if (matches.isEmpty)
              _panelVacio('Sube un CV para ver qué ofertas encajan contigo.')
            else
              for (final match in matches)
                _tarjetaMatch(context, match.oferta, match.score),
            const SizedBox(height: 6),
            Text(
              'Actividad reciente',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            _actividad(context),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onVerCandidaturas,
              child: const Text('Ver mis candidaturas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metrica(BuildContext context, String valor, String titulo) =>
      Container(
        height: 72,
        padding: const EdgeInsets.fromLTRB(11, 10, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7E1F8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const Spacer(),
            Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _tarjetaMatch(
    BuildContext context,
    Map<String, dynamic> oferta,
    int score,
  ) {
    final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
    final modalidad = switch (oferta['modalidad']) {
      'REMOTO' => 'Remoto',
      'HIBRIDO' => 'Híbrido',
      'PRESENCIAL' => 'Presencial',
      _ => '',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => widget.onIrAPestana(1),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.iconTile,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: AppColors.iconInk,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      oferta['titulo'] as String? ?? 'Oferta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (empresa['nombre'] as String? ?? 'Empresa') +
                          (modalidad.isEmpty ? '' : ' · ' + modalidad),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                score.toString() + '%',
                style: TextStyle(
                  color: score >= 80
                      ? AppColors.matchHigh
                      : AppColors.matchMid,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actividad(BuildContext context) {
    if (_conversaciones.isEmpty) {
      return _panelVacio(
        'Todavía no hay actividad. Tus mensajes y cambios aparecerán aquí.',
      );
    }
    final chat = _conversaciones.first;
    final persona = chat['interlocutor'] as Map<String, dynamic>? ?? {};
    final ultimo = chat['ultimoMensaje'] as Map<String, dynamic>? ?? {};
    final nombre = (persona['nombre'] as String? ?? 'Tu reclutador').trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E1F8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre + ' te ha escrito',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  ultimo['contenido'] as String? ??
                      'Tienes una conversación nueva',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _hora(ultimo['createdAt']),
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _hora(Object? fecha) {
    if (fecha is! String) return '';
    final date = DateTime.tryParse(fecha)?.toLocal();
    if (date == null) return '';
    return date.hour.toString().padLeft(2, '0') +
        ':' +
        date.minute.toString().padLeft(2, '0');
  }

  Widget _panelVacio(String texto) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7E1F8)),
    ),
    child: Text(
      texto,
      style: const TextStyle(color: AppColors.muted, fontSize: 13),
    ),
  );
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
    required this.entrevistas,
    required this.onMostrarNotificaciones,
  });

  final Map<String, dynamic> usuario;
  final bool esCandidato;
  final List<Map<String, dynamic>> entrevistas;
  final VoidCallback onMostrarNotificaciones;

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
                  style: TextStyle(
                    color: esquema.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hola, ${usuario['nombre']}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: esCandidato ? 'Notificaciones' : null,
                onPressed: esCandidato ? onMostrarNotificaciones : null,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none),
                    if (entrevistas.isNotEmpty)
                      Positioned(
                        top: -7,
                        right: -8,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: esquema.error,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            entrevistas.length > 9
                                ? '9+'
                                : '${entrevistas.length}',
                            style: TextStyle(
                              color: esquema.onError,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: esquema.primary.withValues(alpha: .22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esCandidato
                        ? 'Postulaciones activas'
                        : 'Ofertas publicadas',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '0',
                    style: TextStyle(
                      color: Colors.white,
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
          GlassPanel(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Padding(
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: esCandidato
                    ? [
                        QuickAction(
                          icono: Icons.search,
                          etiqueta: 'Ofertas',
                          onTap: () => onIrAPestana(1),
                        ),
                        QuickAction(
                          icono: Icons.smart_toy_outlined,
                          etiqueta: 'Autopiloto',
                          onTap: () => onIrAPestana(2),
                        ),
                        QuickAction(
                          icono: Icons.chat_bubble_outline,
                          etiqueta: 'Mensajes',
                          onTap: () => onIrAPestana(3),
                        ),
                        QuickAction(
                          icono: Icons.person_outline,
                          etiqueta: 'Perfil',
                          onTap: () => onIrAPestana(4),
                        ),
                      ]
                    : [
                        QuickAction(
                          icono: Icons.add_business_outlined,
                          etiqueta: 'Publicar',
                          onTap: () => onIrAPestana(1),
                        ),
                        QuickAction(
                          icono: Icons.groups_outlined,
                          etiqueta: 'Candidatos',
                          onTap: () => onIrAPestana(1),
                        ),
                        QuickAction(
                          icono: Icons.chat_bubble_outline,
                          etiqueta: 'Mensajes',
                          onTap: () => onIrAPestana(2),
                        ),
                        QuickAction(
                          icono: Icons.person_outline,
                          etiqueta: 'Perfil',
                          onTap: () => onIrAPestana(3),
                        ),
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
                  onTap: esCandidato
                      ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MisPostulacionesPage(),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _tarjetaResumen(
                  context,
                  icono: esCandidato
                      ? Icons.smart_toy_outlined
                      : Icons.groups_outlined,
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
    VoidCallback? onTap,
  }) {
    final esquema = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: esquema.primary),
              const SizedBox(height: 8),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: esquema.onSurface,
                ),
              ),
              Text(
                titulo,
                style: TextStyle(fontSize: 12, color: esquema.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mensajes ───────────────────────────────────────────────────────────

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
                    style: TextStyle(
                      fontSize: 28,
                      color: esquema.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
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
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AutopilotPage())),
            ),
          if (rol == Rol.candidato) ...[
            _opcionPerfil(
              context,
              icono: Icons.send_outlined,
              titulo: 'Mis candidaturas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MisPostulacionesPage()),
              ),
            ),
            _opcionPerfil(
              context,
              icono: Icons.description_outlined,
              titulo: 'Mis currículums',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MisCvsPage(seleccionable: false),
                ),
              ),
            ),
          ],
          const Divider(height: 32),
          Card(
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              leading: Icon(Icons.logout, color: esquema.error),
              title: Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: esquema.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
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
