import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/chat.service.dart';

class MensajesPage extends StatefulWidget {
  const MensajesPage({super.key, required this.usuarioId});
  final String usuarioId;

  @override
  State<MensajesPage> createState() => _MensajesPageState();
}

class _MensajesPageState extends State<MensajesPage> {
  final _service = ChatService();
  final _busqueda = TextEditingController();
  String _consulta = '';
  late Future<List<Map<String, dynamic>>> _future = _service
      .listarConversaciones();

  Future<void> _recargar() async =>
      setState(() => _future = _service.listarConversaciones());

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Mensajes',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  final unread = (snapshot.data ?? const []).fold<int>(
                    0,
                    (sum, chat) =>
                        sum + ((chat['sinLeer'] as num?)?.toInt() ?? 0),
                  );
                  return Text(
                    unread.toString() + ' sin leer',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: TextField(
            controller: _busqueda,
            onChanged: (value) =>
                setState(() => _consulta = value.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Buscar conversación',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError)
                return _EstadoChat(
                  texto: 'No se pudieron cargar los mensajes.',
                  accion: 'Reintentar',
                  onTap: _recargar,
                );
              final chats = (snapshot.data ?? []).where((chat) {
                if (_consulta.isEmpty) return true;
                final person =
                    chat['interlocutor'] as Map<String, dynamic>? ?? {};
                final job = chat['oferta'] as Map<String, dynamic>? ?? {};
                final name =
                    (person['nombre'] ?? '').toString() +
                    ' ' +
                    (person['apellidos'] ?? '').toString() +
                    ' ' +
                    (job['titulo'] ?? '').toString().toLowerCase();
                return name.contains(_consulta);
              }).toList();
              if (chats.isEmpty)
                return const _EstadoChat(
                  texto:
                      'Aún no tienes conversaciones. Abre una oferta y contacta con su reclutador.',
                );
              return RefreshIndicator(
                onRefresh: _recargar,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final chat = chats[i];
                    final person =
                        chat['interlocutor'] as Map<String, dynamic>? ?? {};
                    final job = chat['oferta'] as Map<String, dynamic>?;
                    final last = chat['ultimoMensaje'] as Map<String, dynamic>?;
                    return GlassPanel(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        leading: CircleAvatar(
                          child: Text(
                            (person['nombre'] as String? ?? '?')
                                .substring(0, 1)
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(
                          '${person['nombre'] ?? ''} ${person['apellidos'] ?? ''}'
                              .trim(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          [
                            if (job?['titulo'] != null) job!['titulo'],
                            last?['contenido'] ?? 'Inicia la conversación',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: (chat['sinLeer'] as num? ?? 0) > 0
                            ? CircleAvatar(
                                radius: 12,
                                child: Text(
                                  '${chat['sinLeer']}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatThreadPage(
                                conversacion: chat,
                                usuarioId: widget.usuarioId,
                              ),
                            ),
                          );
                          if (mounted) _recargar();
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

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
  bool _loading = true, _sending = false;
  String? _error;
  String get _id => widget.conversacion['id'] as String;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final items = await _service.mensajes(_id);
      if (!mounted) return;
      setState(() {
        _mensajes = items;
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients)
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = e.toString();
        });
    }
  }

  Future<void> _enviar() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await _service.enviar(_id, text);
      _input.clear();
      if (mounted)
        setState(() {
          _mensajes.add(sent);
          _error = null;
        });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients)
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final person =
        widget.conversacion['interlocutor'] as Map<String, dynamic>? ??
        widget.conversacion['reclutador'] as Map<String, dynamic>? ??
        {};
    final oferta = widget.conversacion['oferta'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${person['nombre'] ?? ''} ${person['apellidos'] ?? ''}'.trim(),
            ),
            if (oferta?['titulo'] != null)
              Text(
                oferta!['titulo'],
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _mensajes.isEmpty
                  ? Center(child: Text(_error!))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _mensajes.length,
                      itemBuilder: (context, i) {
                        final msg = _mensajes[i];
                        final mine = msg['emisorId'] == widget.usuarioId;
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 11,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .78,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              msg['contenido'] as String? ?? '',
                              style: TextStyle(
                                color: mine
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null && _mensajes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _enviar,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoChat extends StatelessWidget {
  const _EstadoChat({required this.texto, this.accion, this.onTap});
  final String texto;
  final String? accion;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 46,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(texto, textAlign: TextAlign.center),
          if (accion != null)
            TextButton(onPressed: onTap, child: Text(accion!)),
        ],
      ),
    ),
  );
}
