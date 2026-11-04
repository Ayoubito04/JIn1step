import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/candidato.service.dart';
import '../services/chat.service.dart';
import '../services/ofertas.services.dart';
import '../widgets/design_system.dart';
import 'perfil_candidato.dart';

/// Bandeja de conversaciones (pestaña Chat).
class MensajesPage extends StatefulWidget {
  const MensajesPage({super.key, required this.usuarioId});
  final String usuarioId;

  @override
  State<MensajesPage> createState() => _MensajesPageState();
}

class _MensajesPageState extends State<MensajesPage> {
  final _service = ChatService();
  final _busqueda = TextEditingController();
  late Future<_Bandeja> _future = _cargar();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<_Bandeja> _cargar() async {
    final chats = await _service.listarConversaciones();
    final contexto = await _contextoOfertas(conMatch: false);
    return _Bandeja(chats, contexto);
  }

  Future<void> _recargar() async {
    setState(() {
      _future = _cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _recargar,
        child: FutureBuilder<_Bandeja>(
          future: _future,
          builder: (context, snapshot) {
            final bandeja = snapshot.data;
            final sinLeer = bandeja == null
                ? 0
                : bandeja.chats.fold<int>(
                    0,
                    (suma, chat) =>
                        suma + ((chat['sinLeer'] as num?)?.toInt() ?? 0),
                  );
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screen),
              children: [
                ScreenHeader(
                  title: 'Mensajes',
                  subtitle: sinLeer == 0
                      ? null
                      : (sinLeer == 1
                            ? '1 mensaje sin leer'
                            : '$sinLeer mensajes sin leer'),
                ),
                const SizedBox(height: AppSpacing.gap),
                SearchField(
                  controller: _busqueda,
                  label: 'Buscar conversación',
                  hint: 'Nombre, empresa u oferta',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.gap),
                ..._contenido(snapshot, bandeja),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _contenido(AsyncSnapshot<_Bandeja> snapshot, _Bandeja? bandeja) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [_EstadoChat(cargando: true)];
    }
    if (snapshot.hasError || bandeja == null) {
      return [
        _EstadoChat(
          texto: 'No se pudieron cargar los mensajes.',
          accion: 'Reintentar carga',
          onTap: _recargar,
        ),
      ];
    }
    if (bandeja.chats.isEmpty) {
      return const [
        _EstadoChat(
          texto:
              'Aún no tienes conversaciones. Abre una oferta y escribe a su reclutador.',
        ),
      ];
    }
    final filas = [
      for (final chat in bandeja.chats)
        if (_coincide(bandeja, chat)) _fila(bandeja, chat),
    ];
    if (filas.isEmpty) {
      return const [
        _EstadoChat(texto: 'Ninguna conversación coincide con la búsqueda.'),
      ];
    }
    return [PanelList(children: filas)];
  }

  bool _coincide(_Bandeja bandeja, Map<String, dynamic> chat) {
    final consulta = _busqueda.text.trim().toLowerCase();
    if (consulta.isEmpty) return true;
    final persona = chat['interlocutor'] as Map<String, dynamic>? ?? {};
    final oferta = chat['oferta'] as Map<String, dynamic>?;
    final ofertaId = (oferta?['id'] ?? chat['ofertaId']) as String?;
    final ultimo = chat['ultimoMensaje'] as Map<String, dynamic>?;
    final campos = [
      _nombreCompleto(persona),
      oferta?['titulo'],
      ofertaId == null ? null : bandeja.contexto[ofertaId]?.empresa,
      ultimo?['contenido'],
    ];
    return campos.whereType<String>().any(
      (campo) => campo.toLowerCase().contains(consulta),
    );
  }

  Widget _fila(_Bandeja bandeja, Map<String, dynamic> chat) {
    final persona = chat['interlocutor'] as Map<String, dynamic>? ?? {};
    final oferta = chat['oferta'] as Map<String, dynamic>?;
    final ultimo = chat['ultimoMensaje'] as Map<String, dynamic>?;
    final nombre = _nombreCompleto(persona);
    final sinLeer = (chat['sinLeer'] as num?)?.toInt() ?? 0;
    final ofertaId = (oferta?['id'] ?? chat['ofertaId']) as String?;
    final empresa = _esCandidato(chat, widget.usuarioId) && ofertaId != null
        ? bandeja.contexto[ofertaId]?.empresa
        : null;
    return _FilaConversacion(
      nombre: nombre,
      empresa: empresa,
      hora: _etiquetaFecha(ultimo?['createdAt'] ?? chat['createdAt']),
      tituloOferta: oferta?['titulo'] as String?,
      ultimoMensaje:
          ultimo?['contenido'] as String? ?? 'Inicia la conversación',
      sinLeer: sinLeer,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ChatThreadPage(conversacion: chat, usuarioId: widget.usuarioId),
          ),
        );
        if (mounted) _recargar();
      },
    );
  }
}

class _Bandeja {
  const _Bandeja(this.chats, this.contexto);
  final List<Map<String, dynamic>> chats;
  final Map<String, _ContextoOferta> contexto;
}

/// Datos de la oferta que no vienen en la conversación (empresa, modalidad y
/// match). Se completan, si existen, con las ofertas y postulaciones del usuario.
class _ContextoOferta {
  const _ContextoOferta({this.empresa, this.modalidad, this.match});
  final String? empresa;
  final String? modalidad;
  final int? match;

  _ContextoOferta copyWith({int? match}) => _ContextoOferta(
    empresa: empresa,
    modalidad: modalidad,
    match: match ?? this.match,
  );
}

Future<Map<String, _ContextoOferta>> _contextoOfertas({
  required bool conMatch,
}) async {
  final resultado = <String, _ContextoOferta>{};
  try {
    final ofertas = await OfertasService().getAllOfertas();
    for (final oferta in ofertas) {
      final id = oferta['id'] as String?;
      if (id == null) continue;
      final empresa = oferta['empresa'] as Map<String, dynamic>?;
      resultado[id] = _ContextoOferta(
        empresa: empresa?['nombre'] as String?,
        modalidad: switch (oferta['modalidad']) {
          'REMOTO' => 'Remoto',
          'HIBRIDO' => 'Híbrido',
          'PRESENCIAL' => 'Presencial',
          _ => null,
        },
      );
    }
  } catch (_) {
    // Es información complementaria: si falla, la fila se muestra sin ella.
  }
  if (conMatch) {
    try {
      final postulaciones = await CandidatoService().listarPostulaciones();
      for (final postulacion in postulaciones) {
        final oferta = postulacion['oferta'] as Map<String, dynamic>?;
        final id = (postulacion['ofertaId'] ?? oferta?['id']) as String?;
        final score = (postulacion['matchScore'] as num?)?.round();
        if (id == null || score == null) continue;
        resultado[id] = (resultado[id] ?? const _ContextoOferta()).copyWith(
          match: score,
        );
      }
    } catch (_) {
      // Igual que arriba: sin postulación no hay porcentaje que mostrar.
    }
  }
  return resultado;
}

String _nombreCompleto(Map<String, dynamic> persona) =>
    '${persona['nombre'] ?? ''} ${persona['apellidos'] ?? ''}'.trim();

String _inicial(String nombre) =>
    nombre.isEmpty ? '?' : nombre.substring(0, 1).toUpperCase();

bool _esCandidato(Map<String, dynamic> conversacion, String usuarioId) =>
    (conversacion['candidato'] as Map<String, dynamic>?)?['id'] == usuarioId;

/// «10:42» si es de hoy, «Ayer», día de la semana (esta semana) o dd/mm.
String _etiquetaFecha(Object? bruto) {
  if (bruto is! String) return '';
  final fecha = DateTime.tryParse(bruto)?.toLocal();
  if (fecha == null) return '';
  final ahora = DateTime.now();
  final dias = DateTime(
    ahora.year,
    ahora.month,
    ahora.day,
  ).difference(DateTime(fecha.year, fecha.month, fecha.day)).inDays;
  if (dias <= 0) {
    return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }
  if (dias == 1) return 'Ayer';
  if (dias < 7) {
    return const [
      'Lun',
      'Mar',
      'Mié',
      'Jue',
      'Vie',
      'Sáb',
      'Dom',
    ][fecha.weekday - 1];
  }
  return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}';
}

/// Fila de la bandeja: nombre y hora, último mensaje, oferta asociada y
/// contador. El nombre de una conversación sin leer va en 600.
class _FilaConversacion extends StatelessWidget {
  const _FilaConversacion({
    required this.nombre,
    required this.hora,
    required this.ultimoMensaje,
    required this.sinLeer,
    required this.onTap,
    this.empresa,
    this.tituloOferta,
  });

  final String nombre;
  final String? empresa;
  final String hora;
  final String? tituloOferta;
  final String ultimoMensaje;
  final int sinLeer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final noLeida = sinLeer > 0;
    final oferta = tituloOferta == null
        ? 'Sin oferta asociada'
        : [tituloOferta!, ?empresa].join(' · ');
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.rule,
        highlightColor: AppColors.rule,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.tap),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(initial: _inicial(nombre)),
                const SizedBox(width: AppSpacing.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.h2.copyWith(
                                fontWeight: noLeida
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.group),
                          Text(hora, style: AppText.meta),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ultimoMensaje,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: noLeida ? AppText.bodyStrong : AppText.mutedBody,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        oferta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.meta,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.group),
                Column(
                  children: [
                    if (noLeida) ...[
                      UnreadBadge(count: sinLeer),
                      const SizedBox(height: AppSpacing.group),
                    ],
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Conversación con un interlocutor (pantalla secundaria, sin barra inferior).
class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.conversacion,
    required this.usuarioId,
  });
  final Map<String, dynamic> conversacion;
  final String usuarioId;
  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _service = ChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _mensajes = [];
  // Mensajes que ya estaban al abrir la conversación: no se animan. Solo entran
  // animadas las burbujas que se añaden después.
  int _cantidadInicial = 0;
  bool _historialCargado = false;
  bool _loading = true, _sending = false;
  String? _error;
  _ContextoOferta? _contexto;
  String get _id => widget.conversacion['id'] as String;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarContexto();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargarContexto() async {
    final oferta = widget.conversacion['oferta'] as Map<String, dynamic>?;
    final ofertaId =
        (oferta?['id'] ?? widget.conversacion['ofertaId']) as String?;
    // Empresa y match solo tienen sentido para quien se ha postulado.
    if (ofertaId == null ||
        !_esCandidato(widget.conversacion, widget.usuarioId)) {
      return;
    }
    final contexto = await _contextoOfertas(conMatch: true);
    if (mounted) setState(() => _contexto = contexto[ofertaId]);
  }

  Future<void> _cargar() async {
    try {
      final items = await _service.mensajes(_id);
      if (!mounted) return;
      setState(() {
        if (!_historialCargado) {
          _historialCargado = true;
          _cantidadInicial = items.length;
        }
        _mensajes = items;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _enviar() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await _service.enviar(_id, text);
      _input.clear();
      if (mounted) {
        setState(() {
          _mensajes.add(sent);
          _error = null;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: Motion.base,
            curve: Motion.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final persona =
        widget.conversacion['interlocutor'] as Map<String, dynamic>? ??
        widget.conversacion['reclutador'] as Map<String, dynamic>? ??
        {};
    final oferta = widget.conversacion['oferta'] as Map<String, dynamic>?;
    final nombre = _nombreCompleto(persona);
    final primerNombre = (persona['nombre'] as String?)?.trim() ?? '';
    final soyReclutador = !_esCandidato(widget.conversacion, widget.usuarioId);
    final candidato =
        widget.conversacion['candidato'] as Map<String, dynamic>? ?? persona;
    final candidatoId = (candidato['id'] as String?)?.trim() ?? '';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.group,
                AppSpacing.screen,
                AppSpacing.gap,
              ),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Volver a mensajes',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AppSpacing.group),
                  Avatar(initial: _inicial(nombre)),
                  const SizedBox(width: AppSpacing.group),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(nombre, style: AppText.h2),
                        ),
                        if (_contexto?.empresa != null)
                          Text(_contexto!.empresa!, style: AppText.meta),
                      ],
                    ),
                  ),
                  if (soyReclutador && candidatoId.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.group),
                    SecondaryButton(
                      label: 'Ver perfil',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PerfilCandidatoPage(
                              candidatoId: candidatoId,
                              candidatoInicial: candidato,
                              oferta: oferta,
                              reclutadorId: widget.usuarioId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (oferta?['titulo'] != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  0,
                  AppSpacing.screen,
                  AppSpacing.gap,
                ),
                child: _PanelOferta(
                  titulo: oferta!['titulo'] as String,
                  empresaYModalidad: [
                    _contexto?.empresa,
                    _contexto?.modalidad,
                  ].whereType<String>().join(' · '),
                  match: _contexto?.match,
                ),
              ),
            Expanded(child: _mensajesLista()),
            if (_error != null && _mensajes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: Notice(message: _error!, variant: StatusVariant.error),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Composer(
                controller: _input,
                label: primerNombre.isEmpty
                    ? 'Mensaje'
                    : 'Mensaje para $primerNombre',
                sending: _sending,
                onSend: _enviar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensajesLista() {
    if (_loading) return const Center(child: AppSpinner(size: 24));
    if (_error != null && _mensajes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        children: [_EstadoChat(texto: _error!)],
      );
    }
    // «Leído» solo bajo el último mensaje enviado por mí, si ya lo han leído.
    final ultimoMio = _mensajes.lastIndexWhere(
      (m) => m['emisorId'] == widget.usuarioId,
    );
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.group,
      ),
      itemCount: _mensajes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.group),
      itemBuilder: (context, i) {
        final msg = _mensajes[i];
        return ChatBubble(
          message: msg['contenido'] as String? ?? '',
          sentByMe: msg['emisorId'] == widget.usuarioId,
          receipt: i == ultimoMio && msg['leido'] == true ? 'Leído' : null,
          animarEntrada: i >= _cantidadInicial,
        );
      },
    );
  }
}

/// Oferta de la conversación con su match: cifra mono y pasos.
class _PanelOferta extends StatelessWidget {
  const _PanelOferta({
    required this.titulo,
    required this.empresaYModalidad,
    this.match,
  });

  final String titulo;
  final String empresaYModalidad;
  final int? match;

  @override
  Widget build(BuildContext context) => Panel(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Oferta', style: AppText.meta),
              Text(titulo, style: AppText.h2),
              if (empresaYModalidad.isNotEmpty)
                Text(empresaYModalidad, style: AppText.meta),
            ],
          ),
        ),
        if (match != null) ...[
          const SizedBox(width: AppSpacing.gap),
          MatchIndicator(match: match!),
        ],
      ],
    ),
  );
}

/// Carga, vacío o error: mantiene el marco del panel y una frase.
class _EstadoChat extends StatelessWidget {
  const _EstadoChat({
    this.texto,
    this.accion,
    this.onTap,
    this.cargando = false,
  });
  final String? texto;
  final String? accion;
  final VoidCallback? onTap;
  final bool cargando;

  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cargando)
          const Center(child: AppSpinner(size: 24))
        else
          Text(texto ?? '', style: AppText.mutedBody),
        if (accion != null) ...[
          const SizedBox(height: AppSpacing.gap),
          SecondaryButton(label: accion!, onPressed: onTap),
        ],
      ],
    ),
  );
}
