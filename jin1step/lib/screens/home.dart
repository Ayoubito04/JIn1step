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
// Diseño: DESIGN.md ("libro de cuentas"). Todo se compone con los tokens de
// core/app_theme.dart y los componentes de widgets/design_system.dart; aquí no
// se escribe ningún color, tamaño ni radio suelto.
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/auth.service.dart';
import '../services/candidato.service.dart';
import '../services/chat.service.dart';
import '../services/ofertas.services.dart';
import '../widgets/brand_logo.dart';
import '../widgets/design_system.dart';
import 'autopilot.dart';
import 'mis_cvs.dart';
import 'mensajes.dart';
import 'mis_ofertas.dart';
import 'mis_postulaciones.dart';
import 'oferta_detalle.dart';
import 'ofertas.dart';
import 'perfil.dart';
import 'red_candidatos.dart';

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
  final _chatService = ChatService();
  int _mensajesSinLeer = 0;
  List<Map<String, dynamic>> _entrevistas = [];
  final Set<String> _entrevistasLeidas = {};
  // Candidaturas que el autopiloto ha enviado en las últimas 24 h (sin las
  // retiradas). Sirven de aviso: el autopiloto corre solo en el servidor.
  List<Map<String, dynamic>> _autopilotRecientes = [];
  final Set<String> _autopilotLeidas = {};
  // Propuestas del autopiloto que esperan la decisión del usuario.
  List<Map<String, dynamic>> _propuestas = [];
  final Set<String> _propuestasLeidas = {};
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
    unawaited(_cargarMensajesSinLeer());
    _temporizadorNotificaciones = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) {
      unawaited(_cargarEntrevistas());
      unawaited(_cargarMensajesSinLeer());
    });
  }

  /// Contador de mensajes sin leer de todas las conversaciones (`GET /mensajes/sin-leer`):
  /// es el número de la insignia de la pestaña Chat y de la cifra de Inicio
  /// (distinto del contador de la campana).
  Future<void> _cargarMensajesSinLeer() async {
    try {
      final total = await _chatService.contarSinLeer();
      if (mounted && total != _mensajesSinLeer) {
        setState(() => _mensajesSinLeer = total);
      }
    } catch (_) {
      // La insignia es informativa: si falla, se conserva el último valor.
    }
  }

  Future<void> _cargarEntrevistas() async {
    try {
      final postulaciones = await _candidatoService.listarPostulaciones();
      final entrevistas = postulaciones
          .where((postulacion) => postulacion['estado'] == 'ENTREVISTA')
          .toList();
      final recientesIa = postulaciones.where(_esAvisoDeAutopilot).toList();
      final propuestas = postulaciones
          .where((postulacion) => postulacion['estado'] == 'PROPUESTA')
          .toList();
      final idsPropuestasAnteriores = _propuestas
          .map((postulacion) => postulacion['id'])
          .toSet();
      final nuevasPropuestas = _primeraCargaEntrevistas
          ? 0
          : propuestas
                .where(
                  (postulacion) =>
                      !idsPropuestasAnteriores.contains(postulacion['id']),
                )
                .length;
      final idsIaAnteriores = _autopilotRecientes
          .map((postulacion) => postulacion['id'])
          .toSet();
      final nuevasIa = _primeraCargaEntrevistas
          ? 0
          : recientesIa
                .where(
                  (postulacion) => !idsIaAnteriores.contains(postulacion['id']),
                )
                .length;
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
        _autopilotRecientes = recientesIa;
        _propuestas = propuestas;
        _notificacionesCargando = false;
      });
      _primeraCargaEntrevistas = false;

      if (nuevasPropuestas > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevasPropuestas == 1
                  ? 'El autopiloto tiene una propuesta nueva para revisar.'
                  : 'El autopiloto tiene $nuevasPropuestas propuestas nuevas para revisar.',
            ),
          ),
        );
      }

      if (nuevasIa > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevasIa == 1
                  ? 'El autopiloto ha enviado una candidatura nueva.'
                  : 'El autopiloto ha enviado $nuevasIa candidaturas nuevas.',
            ),
          ),
        );
      }

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

  /// Enviada por el autopiloto en las últimas 24 h y no retirada. Las
  /// propuestas tienen su propio aviso (esperan decisión, sea cual sea su edad).
  bool _esAvisoDeAutopilot(Map<String, dynamic> postulacion) {
    if (postulacion['postuladoPorIa'] != true) return false;
    const excluidas = {'RETIRADA', 'PROPUESTA', 'DESCARTADA'};
    if (excluidas.contains(postulacion['estado'])) return false;
    final fecha = DateTime.tryParse(
      postulacion['fechaPostulacion'] as String? ?? '',
    );
    return fecha != null &&
        DateTime.now().difference(fecha) < const Duration(hours: 24);
  }

  void _marcarTodasLeidas() {
    setState(() {
      for (final p in _entrevistas) {
        final id = p['id'];
        if (id is String) _entrevistasLeidas.add(id);
      }
      for (final p in _propuestas) {
        final id = p['id'];
        if (id is String) _propuestasLeidas.add(id);
      }
      for (final p in _autopilotRecientes) {
        final id = p['id'];
        if (id is String) _autopilotLeidas.add(id);
      }
    });
  }

  void _mostrarNotificaciones() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (pageContext) => StatefulBuilder(
          builder: (context, setPageState) {
            final noLeidas =
                _entrevistas
                    .where(
                      (p) =>
                          p['id'] is String &&
                          !_entrevistasLeidas.contains(p['id']),
                    )
                    .length +
                _autopilotRecientes
                    .where(
                      (p) =>
                          p['id'] is String &&
                          !_autopilotLeidas.contains(p['id']),
                    )
                    .length +
                _propuestas
                    .where(
                      (p) =>
                          p['id'] is String &&
                          !_propuestasLeidas.contains(p['id']),
                    )
                    .length;

            return Scaffold(
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screen),
                  children: [
                    Row(
                      children: [
                        AppIconButton(
                          icon: Icons.arrow_back,
                          tooltip: 'Volver a Inicio',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        AppIconButton(
                          icon: Icons.refresh,
                          tooltip: 'Actualizar notificaciones',
                          onPressed: () async {
                            await _cargarEntrevistas();
                            if (context.mounted) setPageState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    ScreenHeader(
                      title: 'Notificaciones',
                      subtitle: noLeidas == 0
                          ? 'Todo al día'
                          : _plural(
                              noLeidas,
                              'notificación sin leer',
                              'notificaciones sin leer',
                            ),
                      trailing: noLeidas > 0
                          ? LinkAction(
                              label: 'Marcar todas como leídas',
                              onTap: () {
                                _marcarTodasLeidas();
                                setPageState(() {});
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.gap),
                    if (_notificacionesCargando &&
                        _entrevistas.isEmpty &&
                        _propuestas.isEmpty &&
                        _autopilotRecientes.isEmpty)
                      const Panel(child: Center(child: AppSpinner(size: 24)))
                    else if (_entrevistas.isEmpty &&
                        _propuestas.isEmpty &&
                        _autopilotRecientes.isEmpty)
                      Panel(
                        child: Text(
                          'No tienes notificaciones pendientes. Te avisaremos cuando haya cambios en tus candidaturas.',
                          style: AppText.mutedBody,
                        ),
                      )
                    else
                      PanelList(
                        children: [
                          for (final postulacion in _entrevistas)
                            _filaEntrevista(context, postulacion),
                          for (final postulacion in _propuestas)
                            _filaPropuesta(context, postulacion),
                          for (final postulacion in _autopilotRecientes)
                            _filaAutopilot(context, postulacion),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filaEntrevista(
    BuildContext context,
    Map<String, dynamic> postulacion,
  ) {
    final id = postulacion['id'];
    final leida = id is String && _entrevistasLeidas.contains(id);
    final oferta = postulacion['oferta'] as Map<String, dynamic>? ?? {};
    final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
    return ListRow(
      title: oferta['titulo'] as String? ?? 'Entrevista',
      strongTitle: !leida,
      lines: [
        '${empresa['nombre'] ?? 'El reclutador'} te ha seleccionado para una entrevista.',
        'Contacta por el chat para acordar fecha y hora.',
      ],
      trailing: leida
          ? const StatusTag(label: 'Leída', variant: StatusVariant.neutral)
          : const StatusTag(label: 'Nueva', variant: StatusVariant.error),
      onTap: () {
        if (id is String) {
          setState(() => _entrevistasLeidas.add(id));
        }
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                MisPostulacionesPage(postulacionId: id is String ? id : null),
          ),
        );
      },
    );
  }

  Widget _filaPropuesta(
    BuildContext context,
    Map<String, dynamic> postulacion,
  ) {
    final id = postulacion['id'];
    final leida = id is String && _propuestasLeidas.contains(id);
    final oferta = postulacion['oferta'] as Map<String, dynamic>? ?? {};
    final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
    return ListRow(
      title: 'El autopiloto te propone ${oferta['titulo'] ?? 'una oferta'}',
      strongTitle: !leida,
      lines: [
        empresa['nombre'] as String? ?? 'Empresa',
        'Revísala y decide si se envía.',
      ],
      trailing: leida
          ? const StatusTag(label: 'Leída', variant: StatusVariant.neutral)
          : const StatusTag(label: 'Nueva', variant: StatusVariant.error),
      onTap: () {
        if (id is String) {
          setState(() => _propuestasLeidas.add(id));
        }
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AutopilotPage(mostrarAtras: true),
          ),
        );
      },
    );
  }

  Widget _filaAutopilot(
    BuildContext context,
    Map<String, dynamic> postulacion,
  ) {
    final id = postulacion['id'];
    final leida = id is String && _autopilotLeidas.contains(id);
    final oferta = postulacion['oferta'] as Map<String, dynamic>? ?? {};
    final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
    return ListRow(
      title: oferta['titulo'] as String? ?? 'Candidatura',
      strongTitle: !leida,
      lines: [
        'El autopiloto te ha postulado en ${empresa['nombre'] ?? 'una empresa'}.',
        'Puedes revisarla o retirarla si no te interesa.',
      ],
      trailing: leida
          ? const StatusTag(label: 'Leída', variant: StatusVariant.neutral)
          : const StatusTag(label: 'Nueva', variant: StatusVariant.error),
      onTap: () {
        if (id is String) {
          setState(() => _autopilotLeidas.add(id));
        }
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                MisPostulacionesPage(postulacionId: id is String ? id : null),
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

  void _irAPestana(int indice) {
    setState(() {
      _indice = indice;
      if (indice == (_rol == Rol.candidato ? 3 : 2)) _versionMensajes++;
    });
    if (_rol == Rol.candidato) unawaited(_cargarMensajesSinLeer());
  }

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
          iconoActivo: Icons.home_outlined,
          pagina: _InicioCandidatoTab(
            usuario: usuario,
            notificacionesNoLeidas:
                _entrevistas
                    .where(
                      (p) =>
                          p['id'] is String &&
                          !_entrevistasLeidas.contains(p['id']),
                    )
                    .length +
                _autopilotRecientes
                    .where(
                      (p) =>
                          p['id'] is String &&
                          !_autopilotLeidas.contains(p['id']),
                    )
                    .length +
                _propuestas
                    .where(
                      (p) =>
                          p['id'] is String &&
                          !_propuestasLeidas.contains(p['id']),
                    )
                    .length,
            mensajesSinLeer: _mensajesSinLeer,
            onMostrarNotificaciones: _mostrarNotificaciones,
            onIrAPestana: _irAPestana,
            onVerCandidaturas: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MisPostulacionesPage()),
            ),
            onVerPerfil: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PerfilPage(usuario: usuario, mostrarAtras: true),
              ),
            ),
          ),
        ),
        _Seccion(
          etiqueta: 'Ofertas',
          icono: Icons.work_outline,
          iconoActivo: Icons.work_outline,
          pagina: Ofertas(ofertaService: widget.ofertasService),
        ),
        _Seccion(
          etiqueta: 'Autopiloto',
          icono: Icons.bolt_outlined,
          iconoActivo: Icons.bolt_outlined,
          pagina: const AutopilotPage(),
        ),
        _Seccion(
          etiqueta: 'Chat',
          icono: Icons.chat_bubble_outline,
          iconoActivo: Icons.chat_bubble_outline,
          pagina: MensajesPage(
            key: ValueKey(_versionMensajes),
            usuarioId: usuario['id'] as String,
          ),
        ),
        _Seccion(
          etiqueta: 'Mi CV',
          icono: Icons.person_outline,
          iconoActivo: Icons.person_outline,
          pagina: MisCvsPage(
            seleccionable: false,
            onVerPerfil: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PerfilPage(usuario: usuario, mostrarAtras: true),
              ),
            ),
          ),
        ),
      ] else ...[
        _Seccion(
          etiqueta: 'Inicio',
          icono: Icons.home_outlined,
          iconoActivo: Icons.home,
          pagina: _InicioTab(usuario: usuario, onIrAPestana: _irAPestana),
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
          pagina: PerfilPage(usuario: usuario),
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
      // Candidato: BottomNav del sistema de diseño (5 pestañas del PDF, con la
      // insignia de mensajes sin leer sobre Chat). El diseño no cubre al
      // reclutador, que mantiene su NavigationBar con el estilo del tema.
      bottomNavigationBar: esCandidato
          ? BottomNav(
              selectedIndex: _indice,
              unreadMessages: _mensajesSinLeer,
              items: [
                for (var i = 0; i < secciones.length; i++)
                  BottomNavItem(
                    label: secciones[i].etiqueta,
                    icon: secciones[i].icono,
                    onTap: () => _irAPestana(i),
                  ),
              ],
            )
          : NavigationBar(
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

String _plural(int n, String uno, String varios) =>
    '$n ${n == 1 ? uno : varios}';

/// Inicio del candidato (DESIGN.md): marca y campana, «Hoy» con la frase de
/// lo más importante, cuatro cifras y los dos mejores matches. Todo sale de
/// datos reales del backend.
class _InicioCandidatoTab extends StatefulWidget {
  const _InicioCandidatoTab({
    required this.usuario,
    required this.notificacionesNoLeidas,
    required this.mensajesSinLeer,
    required this.onMostrarNotificaciones,
    required this.onIrAPestana,
    required this.onVerCandidaturas,
    required this.onVerPerfil,
  });

  final Map<String, dynamic> usuario;
  final VoidCallback onVerPerfil;
  final int notificacionesNoLeidas;
  final int mensajesSinLeer;
  final VoidCallback onMostrarNotificaciones;
  final ValueChanged<int> onIrAPestana;
  final VoidCallback onVerCandidaturas;

  @override
  State<_InicioCandidatoTab> createState() => _InicioCandidatoTabState();
}

class _InicioCandidatoTabState extends State<_InicioCandidatoTab> {
  final _candidato = CandidatoService();
  final _ofertas = OfertasService();
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _postulaciones = [];
  List<Map<String, dynamic>> _ofertasDisponibles = [];
  Map<String, dynamic> _preferencias = {};
  Set<String> _habilidades = {};

  @override
  void initState() {
    super.initState();
    _cargar();
    unawaited(_cargarFotoPerfil());
  }

  Future<void> _cargarFotoPerfil() async {
    try {
      await _candidato.obtenerMiPerfil();
    } catch (_) {
      // Si falla la carga del perfil opcional, el avatar muestra la inicial.
    }
  }

  Future<void> _cargar() async {
    try {
      final datos = await Future.wait<Object?>([
        _candidato.listarPostulaciones(),
        _candidato.obtenerPreferenciasAutopilot(),
        _ofertas.getAllOfertas(),
        _candidato.listarCvs(),
      ]);
      final cvs = datos[3] as List<Map<String, dynamic>>;
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
            .map(MatchOferta.normalizar)
            .toSet()
          ..addAll(
            MatchOferta.extraerTerminosDeTexto(
              cvs.first['contenidoTexto'] as String?,
            ),
          );
      }
      if (!mounted) return;
      setState(() {
        // Sin propuestas pendientes ni descartadas: no son candidaturas.
        _postulaciones = (datos[0] as List<Map<String, dynamic>>)
            .where(esCandidaturaEnviada)
            .toList();
        _preferencias = datos[1] as Map<String, dynamic>;
        _ofertasDisponibles = datos[2] as List<Map<String, dynamic>>;
        _habilidades = habilidades;
        _cargando = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _cargando = false;
        });
      }
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
    final resultado = MatchOferta.calcular(oferta, _habilidades);
    if (resultado.obligatoriasTotal == 0 &&
        resultado.deseablesTotal == 0 &&
        resultado.descripcionTotal == 0) {
      return null;
    }
    return resultado.score;
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
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: _cargando
        ? const Center(child: AppSpinner(size: 24))
        : _error != null
        ? _vistaError()
        : _contenido(),
  );

  Widget _vistaError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No se pudo cargar tu resumen', style: AppText.h2),
          const SizedBox(height: AppSpacing.group),
          Text(_error!, textAlign: TextAlign.center, style: AppText.meta),
          const SizedBox(height: AppSpacing.gap),
          SecondaryButton(
            label: 'Reintentar carga',
            onPressed: () {
              setState(() {
                _cargando = true;
                _error = null;
              });
              _cargar();
            },
          ),
        ],
      ),
    ),
  );

  /// Frase con lo más importante: qué espera respuesta y qué hizo el
  /// autopiloto hoy.
  String _frase({
    required int entrevistas,
    required bool activo,
    required int hoy,
    required int limite,
  }) {
    final partes = [
      if (entrevistas > 0) _plural(entrevistas, 'entrevista', 'entrevistas'),
      if (widget.mensajesSinLeer > 0)
        _plural(
          widget.mensajesSinLeer,
          'mensaje sin leer',
          'mensajes sin leer',
        ),
    ];
    final principal = partes.isEmpty
        ? 'Todo al día. Revisa las ofertas que encajan contigo.'
        : 'Tienes ${partes.join(' y ')}.';
    if (!activo) return principal;
    final hoyMostrado = hoy.clamp(0, limite);
    return '$principal El autopiloto ha enviado $hoyMostrado de $limite candidaturas hoy.';
  }

  Widget _contenido() {
    final entrevistas = _postulaciones
        .where((p) => p['estado'] == 'ENTREVISTA')
        .length;
    final pendientes = _postulaciones
        .where((p) => p['estado'] == 'PENDIENTE' || p['estado'] == 'ENVIADA')
        .length;
    final hoy = _postulaciones
        .where(
          (p) => p['postuladoPorIa'] == true && _esHoy(p['fechaPostulacion']),
        )
        .length;
    final limite = (_preferencias['maxPorDia'] as num?)?.toInt() ?? 5;
    final activo = _preferencias['activo'] == true;
    final matches = _mejores;

    final nombreUsuario = (widget.usuario['nombre'] as String? ?? '').trim();
    final correoUsuario = widget.usuario['email'] as String? ?? '';
    final inicialUsuario = nombreUsuario.isEmpty
        ? 'U'
        : nombreUsuario[0].toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        Row(
          children: [
            const BrandLogo(size: 40),
            const SizedBox(width: AppSpacing.group),
            Expanded(child: Text('JIn1Step', style: AppText.h2)),
            Tooltip(
              message: 'Editar mi perfil',
              child: Semantics(
                button: true,
                label: 'Editar mi perfil',
                excludeSemantics: true,
                child: InkWell(
                  onTap: widget.onVerPerfil,
                  customBorder: const CircleBorder(),
                  child: SizedBox.square(
                    dimension: AppSpacing.tap,
                    child: Center(
                      child: ValueListenableBuilder<String?>(
                        valueListenable: CandidatoService.fotoPerfilActual,
                        builder: (context, fotoUrl, _) => Avatar(
                          initial: inicialUsuario,
                          seed: correoUsuario,
                          size: 40,
                          imageUrl: fotoUrl,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.group),
            NotificationBell(
              count: widget.notificacionesNoLeidas,
              onPressed: widget.onMostrarNotificaciones,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.gap),
        ScreenHeader(
          title: 'Hoy',
          subtitle: _frase(
            entrevistas: entrevistas,
            activo: activo,
            hoy: hoy,
            limite: limite,
          ),
        ),
        const SizedBox(height: AppSpacing.gap),
        KpiGrid(
          items: [
            KpiItem(
              'Candidaturas',
              '${_postulaciones.length}',
              onTap: widget.onVerCandidaturas,
            ),
            KpiItem(
              'Entrevistas',
              '$entrevistas',
              onTap: widget.onVerCandidaturas,
            ),
            KpiItem(
              'Pendientes de revisión',
              '$pendientes',
              onTap: widget.onVerCandidaturas,
            ),
            KpiItem(
              'Mensajes sin leer',
              '${widget.mensajesSinLeer}',
              onTap: () => widget.onIrAPestana(3),
            ),
          ],
        ),
        LinkAction(
          label: 'Ver mis candidaturas',
          onTap: widget.onVerCandidaturas,
        ),
        const SizedBox(height: AppSpacing.group),
        SectionTitle(
          'Mejores matches',
          trailing: LinkAction(
            label: 'Ver todas las ofertas',
            onTap: () => widget.onIrAPestana(1),
          ),
        ),
        const SizedBox(height: AppSpacing.group),
        if (matches.isEmpty)
          Panel(
            child: Text(
              'Sube un CV para ver qué ofertas encajan contigo.',
              style: AppText.mutedBody,
            ),
          )
        else
          PanelList(
            children: [
              for (final match in matches)
                _filaMatch(match.oferta, match.score),
            ],
          ),
        const SizedBox(height: AppSpacing.gap),
        SectionTitle(
          'Red profesional',
          trailing: LinkAction(
            label: 'Explorar candidatos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RedCandidatosPage()),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.group),
        PanelList(
          children: [
            ListRow(
              title: 'Comunidad de candidatos',
              lines: const [
                'Sigue a otros profesionales en un clic y consulta su perfil público.',
              ],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RedCandidatosPage()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filaMatch(Map<String, dynamic> oferta, int score) {
    final empresa = oferta['empresa'] as Map<String, dynamic>? ?? {};
    final modalidad = switch (oferta['modalidad']) {
      'REMOTO' => 'Remoto',
      'HIBRIDO' => 'Híbrido',
      'PRESENCIAL' => 'Presencial',
      _ => '',
    };
    final salario = (oferta['salario'] as String?)?.trim() ?? '';
    final subtitulo = [
      empresa['nombre'] as String? ?? 'Empresa',
      if (modalidad.isNotEmpty) modalidad,
      if (salario.isNotEmpty) salario,
    ].join(' · ');
    return ListRow(
      title: oferta['titulo'] as String? ?? 'Oferta',
      lines: [subtitulo],
      trailing: MatchIndicator(match: score),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              OfertaDetalle(oferta: oferta, habilidadesCv: _habilidades),
        ),
      ),
    );
  }
}

// ─── Inicio del reclutador ──────────────────────────────────────────────

/// Resumen del reclutador. Queda fuera del rediseño del candidato: solo usa
/// los componentes del sistema para que encaje con el tema.
///
/// TODO: sustituir los valores fijos ("0") por GET /ofertas/mias y los
/// candidatos recibidos.
class _InicioTab extends StatelessWidget {
  const _InicioTab({required this.usuario, required this.onIrAPestana});

  final Map<String, dynamic> usuario;

  /// Las filas saltan a otra pestaña de la barra en vez de duplicar su
  /// contenido aquí.
  final void Function(int indice) onIrAPestana;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
        ScreenHeader(
          title: 'Hola, ${usuario['nombre']}',
          subtitle: 'Esto es lo que está pasando con tus ofertas',
        ),
        const SizedBox(height: AppSpacing.gap),
        const KpiGrid(
          items: [KpiItem('Ofertas abiertas', '0'), KpiItem('Candidatos', '0')],
        ),
        const SizedBox(height: AppSpacing.gap),
        PanelList(
          children: [
            ListRow(title: 'Publicar oferta', onTap: () => onIrAPestana(1)),
            ListRow(title: 'Ver candidatos', onTap: () => onIrAPestana(1)),
            ListRow(title: 'Mensajes', onTap: () => onIrAPestana(2)),
            ListRow(title: 'Perfil', onTap: () => onIrAPestana(3)),
          ],
        ),
      ],
    ),
  );
}
