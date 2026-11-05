import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

enum StatusVariant { neutral, success, warning, error }

/// Cifra de pasos de un match: ceil(match / 20), de 0 a 5.
int pasosDeMatch(num match) => (match / 20).ceil().clamp(0, 5);

Color tinteDePersona(String semilla) {
  final tintes = AppColors.personTints;
  final suma = semilla.runes.fold<int>(0, (a, b) => a + b);
  return tintes[suma % tintes.length];
}

bool _sinMovimiento(BuildContext context) => reduce(context);

/// Feedback de pulsación (animation.md): escala a 0.97 durante `Motion.press`.
/// Escucha el puntero sin competir con el gesto del hijo. Con movimiento
/// reducido no escala.
class _Pulsable extends StatefulWidget {
  const _Pulsable({required this.child, this.activo = true});

  final Widget child;
  final bool activo;

  @override
  State<_Pulsable> createState() => _PulsableState();
}

class _PulsableState extends State<_Pulsable> {
  bool _pulsado = false;

  void _cambiar(bool pulsado) {
    if (_pulsado != pulsado && mounted) setState(() => _pulsado = pulsado);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _cambiar(true),
    onPointerUp: (_) => _cambiar(false),
    onPointerCancel: (_) => _cambiar(false),
    child: AnimatedScale(
      scale: _pulsado && widget.activo && !_sinMovimiento(context) ? 0.97 : 1,
      duration: Motion.press,
      curve: Motion.easeOut,
      child: widget.child,
    ),
  );
}

// ---------------------------------------------------------------------------
// Fondo
// ---------------------------------------------------------------------------

/// `ground` plano más líneas finas y orgánicas, quietas y detrás del
/// contenido. Es el único responsable del fondo: se aplica una vez en main.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.ground,
    child: Stack(
      fit: StackFit.expand,
      children: [
        const IgnorePointer(
          child: RepaintBoundary(child: CustomPaint(painter: _LinesPainter())),
        ),
        child,
      ],
    ),
  );
}

class _LinesPainter extends CustomPainter {
  const _LinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = AppColors.data.withValues(alpha: .14);

    final lineas = <Path>[
      Path()
        ..moveTo(-20, h * .12)
        ..cubicTo(w * .25, h * .02, w * .55, h * .24, w + 20, h * .1),
      Path()
        ..moveTo(-20, h * .3)
        ..cubicTo(w * .3, h * .42, w * .6, h * .16, w + 20, h * .34),
      Path()
        ..moveTo(-20, h * .62)
        ..cubicTo(w * .22, h * .52, w * .5, h * .78, w + 20, h * .6),
      Path()
        ..moveTo(-20, h * .86)
        ..cubicTo(w * .3, h * .96, w * .62, h * .72, w + 20, h * .88),
    ];
    for (final linea in lineas) {
      canvas.drawPath(linea, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinesPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Paneles y listas
// ---------------------------------------------------------------------------

/// Superficie con borde de 1 px: nunca lleva sombra ni degradado.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.gap),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );
}

/// Las pantallas de reclutador siguen usando este nombre.
class GlassPanel extends Panel {
  const GlassPanel({super.key, required super.child, super.padding});
}

/// Lista de filas dentro de UN solo panel, separadas por líneas `rule`.
class PanelList extends StatelessWidget {
  const PanelList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(color: AppColors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(),
          children[i],
        ],
      ],
    ),
  );
}

class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.lines = const [],
    this.leading,
    this.trailing,
    this.onTap,
    this.strongTitle = true,
  });

  final String title;
  final List<String> lines;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool strongTitle;

  @override
  Widget build(BuildContext context) {
    final contenido = Padding(
      padding: const EdgeInsets.all(AppSpacing.gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.h2.copyWith(
                    fontWeight: strongTitle ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                for (final linea in lines) ...[
                  const SizedBox(height: 2),
                  Text(linea, style: AppText.mutedBody),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.group),
            trailing!,
          ],
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.group),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.muted),
          ],
        ],
      ),
    );
    if (onTap == null) return contenido;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.active,
        highlightColor: AppColors.active,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.tap),
          child: contenido,
        ),
      ),
    );
  }
}

class KpiItem {
  const KpiItem(this.label, this.value, {this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;
}

/// Cuadrícula 2×2 dividida por líneas `rule` de 1 px. Cuando una celda navega
/// a una vista de detalle incluye un chevron de 16 px arriba a la derecha y
/// estado presionado `active`.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.items});

  final List<KpiItem> items;

  Widget _celda(KpiItem item) {
    final contenido = Padding(
      padding: const EdgeInsets.all(AppSpacing.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.label, style: AppText.meta)),
              if (item.onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.muted,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(item.value, style: AppText.kpi),
        ],
      ),
    );
    if (item.onTap == null) return contenido;
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          hoverColor: AppColors.active,
          highlightColor: AppColors.active,
          child: contenido,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filas = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      final izquierda = items[i];
      final derecha = i + 1 < items.length ? items[i + 1] : null;
      if (i > 0) filas.add(const Divider());
      filas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _celda(izquierda)),
              const VerticalDivider(),
              Expanded(
                child: derecha == null ? const SizedBox() : _celda(derecha),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: filas),
    );
  }
}

// ---------------------------------------------------------------------------
// Pasos, etiquetas y avisos
// ---------------------------------------------------------------------------

/// El elemento propio: escalera de barras ascendentes (match de 5 pasos,
/// nivel de habilidad de 3, cupo diario de 5). Siempre va junto a una cifra
/// o un texto, nunca solo.
///
/// Con `animar` cada barra crece desde la base al aparecer, escalonadas 40 ms
/// (animation.md). Solo se usa en el glifo grande del detalle y en el cupo; en
/// las filas de las listas va quieto.
class Steps extends StatefulWidget {
  const Steps({
    super.key,
    required this.filled,
    this.total = 5,
    this.animar = false,
  });

  final int filled;
  final int total;
  final bool animar;

  @override
  State<Steps> createState() => _StepsState();
}

class _StepsState extends State<Steps> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _arrancado = false;
  int _desde = 0;
  late int _hasta = _cuenta;

  int get _cuenta => widget.total == 3 ? 3 : 5;

  void _iniciarAnimacion({required int desde, required int hasta}) {
    _desde = desde;
    _hasta = hasta;
    final cantidad = (hasta - desde).clamp(1, _cuenta);
    // Con movimiento reducido solo un fundido de 150 ms.
    final duracion = _sinMovimiento(context)
        ? Motion.fast
        : Motion.base + Motion.stagger * (cantidad - 1);
    final controller = _controller ??= AnimationController(vsync: this);
    controller
      ..duration = duracion
      ..forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animar || _arrancado) return;
    _arrancado = true;
    _iniciarAnimacion(desde: 0, hasta: _cuenta);
  }

  @override
  void didUpdateWidget(covariant Steps oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.animar) return;
    if (!oldWidget.animar && !_arrancado) {
      _arrancado = true;
      _iniciarAnimacion(desde: 0, hasta: _cuenta);
      return;
    }
    if (widget.filled > oldWidget.filled) {
      _iniciarAnimacion(
        desde: oldWidget.filled.clamp(0, _cuenta),
        hasta: widget.filled.clamp(0, _cuenta),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Progreso (0..1) de la barra [i], con su retraso escalonado.
  double _progreso(int i) {
    if (i < _desde || i >= _hasta) return 1;
    final controller = _controller!;
    final total = controller.duration!.inMicroseconds;
    if (_sinMovimiento(context)) {
      return Motion.easeOut.transform(controller.value);
    }
    final orden = i - _desde;
    final inicio = (Motion.stagger * orden).inMicroseconds / total;
    final fin = (Motion.stagger * orden + Motion.base).inMicroseconds / total;
    final t = ((controller.value - inicio) / (fin - inicio)).clamp(0.0, 1.0);
    return Motion.easeOut.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final alturas = widget.total == 3
        ? const [6.0, 11.0, 16.0]
        : const [4.0, 7.0, 10.0, 13.0, 16.0];

    Widget barra(int i, double t) {
      final base = Container(
        width: 4,
        height: alturas[i],
        decoration: BoxDecoration(
          color: i < widget.filled ? AppColors.data : AppColors.control,
          borderRadius: BorderRadius.circular(1),
        ),
      );
      if (t >= 1) return base;
      return Opacity(
        opacity: t,
        child: Transform.scale(
          scaleY: _sinMovimiento(context) ? 1 : 0.25 + 0.75 * t,
          alignment: Alignment.bottomCenter,
          child: base,
        ),
      );
    }

    Widget fila(double Function(int) progreso) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < alturas.length; i++) ...[
          if (i > 0) const SizedBox(width: 2),
          barra(i, progreso(i)),
        ],
      ],
    );

    return ExcludeSemantics(
      child: SizedBox(
        height: 16,
        child: _controller == null
            ? fila((_) => 1)
            : AnimatedBuilder(
                animation: _controller!,
                builder: (context, _) => fila(_progreso),
              ),
      ),
    );
  }
}

/// Cifra de match en mono con sus cinco pasos.
class MatchIndicator extends StatelessWidget {
  const MatchIndicator({super.key, required this.match});

  final num match;

  @override
  Widget build(BuildContext context) {
    final cifra = match.round();
    return Semantics(
      label: 'Match del $cifra %',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$cifra %', style: AppText.numInline),
            const SizedBox(width: AppSpacing.group),
            Steps(filled: pasosDeMatch(match)),
          ],
        ),
      ),
    );
  }
}

class StatusTag extends StatelessWidget {
  const StatusTag({
    super.key,
    required this.label,
    this.variant = StatusVariant.neutral,
  });

  final String label;
  final StatusVariant variant;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto, borde) = switch (variant) {
      StatusVariant.neutral => (
        AppColors.tagNeutralBg,
        AppColors.tagNeutralText,
        null,
      ),
      StatusVariant.success => (
        AppColors.tagSuccessBg,
        AppColors.tagSuccessText,
        null,
      ),
      StatusVariant.warning => (
        AppColors.tagWarningBg,
        AppColors.tagWarningText,
        AppColors.tagWarningBorder,
      ),
      StatusVariant.error => (
        AppColors.tagErrorBg,
        AppColors.tagErrorText,
        null,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppRadii.tag),
        border: borde == null ? null : Border.all(color: borde),
      ),
      child: Text(label, style: AppText.metaStrong.copyWith(color: texto)),
    );
  }
}

/// Bloque de aviso contextual a nivel de pantalla (`InlineNotice`, radio 8,
/// relleno 12×16, borde de 1 px). Variantes: `warning`, `error` (`negative`) y
/// `success` (`positive`).
class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.message,
    this.variant = StatusVariant.warning,
  });

  final String message;
  final StatusVariant variant;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto, borde) = switch (variant) {
      StatusVariant.neutral => (
        AppColors.tagNeutralBg,
        AppColors.tagNeutralText,
        AppColors.border,
      ),
      StatusVariant.success => (
        AppColors.tagSuccessBg,
        AppColors.tagSuccessText,
        AppColors.tagSuccessBorder,
      ),
      StatusVariant.warning => (
        AppColors.tagWarningBg,
        AppColors.tagWarningText,
        AppColors.tagWarningBorder,
      ),
      StatusVariant.error => (
        AppColors.tagErrorBg,
        AppColors.tagErrorText,
        AppColors.tagErrorBorder,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(color: borde),
        ),
        child: Text(message, style: AppText.body.copyWith(color: texto)),
      ),
    );
  }
}

/// Alias explícito del diseño (`InlineNotice`) para avisos contextuales.
class InlineNotice extends Notice {
  const InlineNotice({
    super.key,
    required super.message,
    super.variant = StatusVariant.warning,
  });
}

// ---------------------------------------------------------------------------
// Botones y controles
// ---------------------------------------------------------------------------

class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.white : AppColors.text;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label $count',
      excludeSemantics: true,
      child: _Pulsable(
        child: Material(
          animationDuration: Motion.fast,
          color: selected ? AppColors.ink : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
            side: BorderSide(
              color: selected ? AppColors.ink : AppColors.control,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.tap),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      style: AppText.label.copyWith(color: color),
                      duration: Motion.fast,
                      child: Text(label),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      AnimatedDefaultTextStyle(
                        style: AppText.numInline.copyWith(color: color),
                        duration: Motion.fast,
                        child: Text('$count'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key, this.size = 18, this.color = AppColors.ink});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}

/// Botón principal: plano, casi negro. Nunca se desactiva; mientras carga
/// ignora los toques.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: loading ? 0.88 : 1.0,
    duration: _sinMovimiento(context) ? Duration.zero : Motion.press,
    child: _BotonBase(
      label: loading ? (loadingLabel ?? label) : label,
      onPressed: loading ? null : onPressed,
      leading: loading
          ? const AppSpinner(size: 16, color: AppColors.white)
          : leading,
      fondo: AppColors.ink,
      texto: AppColors.white,
      inactivoVisual: false,
    ),
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => _BotonBase(
    label: label,
    onPressed: onPressed,
    leading: leading,
    fondo: AppColors.activeButton,
    texto: AppColors.text,
  );
}

class _BotonBase extends StatelessWidget {
  const _BotonBase({
    required this.label,
    required this.onPressed,
    required this.leading,
    required this.fondo,
    required this.texto,
    this.inactivoVisual = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Color fondo;
  final Color texto;
  final bool inactivoVisual;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: _Pulsable(
      activo: onPressed != null,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadii.control),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.field,
              minWidth: double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppText.button.copyWith(color: texto),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Campo con etiqueta visible encima (14/500) enlazada al campo para los
/// lectores de pantalla. El marcador solo da un ejemplo de formato.
///
/// Validación (DESIGN.md, formularios): no se marca como inválido mientras se
/// escribe por primera vez; se valida al salir del campo y el error se limpia
/// al volver a enfocarlo. El envío del formulario valida todos los campos.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.validator,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.autocorrect = true,
    this.autofillHints,
    this.maxLines = 1,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autocorrect;
  final Iterable<String>? autofillHints;
  final int maxLines;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _campo = GlobalKey<FormFieldState<String>>();
  FocusNode? _propio;
  late FocusNode _foco = widget.focusNode ?? (_propio = FocusNode());

  @override
  void initState() {
    super.initState();
    _foco.addListener(_alCambiarFoco);
  }

  @override
  void didUpdateWidget(covariant AppTextField anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.focusNode == widget.focusNode) return;
    _foco.removeListener(_alCambiarFoco);
    _propio?.dispose();
    _propio = null;
    _foco = widget.focusNode ?? (_propio = FocusNode());
    _foco.addListener(_alCambiarFoco);
  }

  @override
  void dispose() {
    _foco.removeListener(_alCambiarFoco);
    _propio?.dispose();
    super.dispose();
  }

  /// Al salir del campo se valida; al volver a él se limpia el error.
  /// (`reset` solo borra el error: el texto lo guarda el controlador.)
  void _alCambiarFoco() {
    final estado = _campo.currentState;
    if (estado == null) return;
    if (_foco.hasFocus) {
      estado.reset();
    } else {
      estado.validate();
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExcludeSemantics(child: Text(widget.label, style: AppText.label)),
      const SizedBox(height: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.field),
        child: FormField<String>(
          key: _campo,
          validator: (_) => widget.validator?.call(widget.controller.text),
          builder: (estado) => MergeSemantics(
            child: Semantics(
              label: widget.label,
              child: TextField(
                controller: widget.controller,
                focusNode: _foco,
                enabled: widget.enabled,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                onChanged: (valor) {
                  estado.didChange(valor);
                  widget.onChanged?.call(valor);
                },
                autocorrect: widget.autocorrect,
                autofillHints: widget.autofillHints,
                maxLines: widget.obscureText ? 1 : widget.maxLines,
                style: AppText.field,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  suffixIcon: widget.suffix,
                  errorText: estado.errorText,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

/// Campo de búsqueda: etiqueta visible y lupa.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.label),
      const SizedBox(height: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.field),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: AppText.field,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(
              Icons.search,
              size: 20,
              color: AppColors.muted,
            ),
          ),
        ),
      ),
    ],
  );
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: _Pulsable(
        activo: onPressed != null,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onPressed,
            hoverColor: AppColors.active,
            highlightColor: AppColors.active,
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: SizedBox.square(
              dimension: AppSpacing.tap,
              child: Icon(icon, size: 20, color: AppColors.text),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Campana de Inicio. Su contador es de notificaciones, distinto del de Chat.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSpacing.tap + 6,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          bottom: 0,
          child: AppIconButton(
            icon: Icons.notifications_none,
            tooltip: 'Ver notificaciones',
            onPressed: onPressed,
          ),
        ),
        if (count > 0)
          Positioned(
            top: 0,
            right: 0,
            child: _Contador(
              count: count,
              size: 20,
              bordeColor: AppColors.ground,
            ),
          ),
      ],
    ),
  );
}

class _Contador extends StatelessWidget {
  const _Contador({required this.count, required this.size, this.bordeColor});

  final int count;
  final double size;
  final Color? bordeColor;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AppColors.negative,
      shape: BoxShape.circle,
      border: bordeColor == null
          ? null
          : Border.all(color: bordeColor!, width: 2),
    ),
    child: Text(
      '$count',
      style: AppText.badgeMono,
    ),
  );
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count mensajes sin leer',
    excludeSemantics: true,
    child: _Contador(count: count, size: 20),
  );
}

/// Interruptor 40×24, pista `control`, activo `ink`, mando blanco. La
/// transición dura 150 ms y se anula con movimiento reducido.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final duracion = _sinMovimiento(context) ? Duration.zero : Motion.fast;
    return Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: AppSpacing.tap,
          height: AppSpacing.tap,
          child: Center(
            child: AnimatedContainer(
              duration: duracion,
              curve: Motion.easeOut,
              width: 40,
              height: 24,
              padding: const EdgeInsets.all(2),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? AppColors.ink : AppColors.control,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opción de un selector de radio (p. ej. Candidato/a · Reclutador/a).
class AppRadioRow extends StatelessWidget {
  const AppRadioRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.tap),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.ink : AppColors.control,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.ink,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppText.body)),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Encabezados
// ---------------------------------------------------------------------------

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(title, style: AppText.h1)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: AppText.mutedBody),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ],
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Semantics(header: true, child: Text(text, style: AppText.h2)),
      ),
      ?trailing,
    ],
  );
}

/// Enlace de acción en `data` con verbo en infinitivo, área táctil de 44 px.
class LinkAction extends StatelessWidget {
  const LinkAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    link: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.tap),
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: Text(
            label,
            style: AppText.button.copyWith(color: AppColors.data),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Chat y personas
// ---------------------------------------------------------------------------

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initial,
    this.seed,
    this.size = 40,
    this.imageUrl,
  });

  final String initial;
  final String? seed;
  final double size;
  final String? imageUrl;

  static Uint8List? _decodificarDataUri(String? uri) {
    if (uri == null) return null;
    final limpio = uri.trim();
    if (!limpio.startsWith('data:image/')) return null;
    final coma = limpio.indexOf(',');
    if (coma == -1 || coma + 1 >= limpio.length) return null;
    try {
      return base64Decode(limpio.substring(coma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decodificarDataUri(imageUrl);
    final urlRed =
        bytes == null &&
            imageUrl != null &&
            (imageUrl!.startsWith('http://') ||
                imageUrl!.startsWith('https://'))
        ? imageUrl!
        : null;

    return Semantics(
      image: true,
      label: 'Avatar $initial',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tinteDePersona(seed ?? initial),
        ),
        child: bytes != null
            ? Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : urlRed != null
            ? Image.network(
                urlRed,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Text(initial, style: AppText.h2),
              )
            : Text(initial, style: AppText.h2),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.sentByMe,
    this.receipt,
    this.animarEntrada = false,
  });

  final String message;
  final bool sentByMe;
  final String? receipt;

  /// Solo para burbujas que llegan con la conversación ya abierta: entran con
  /// 8 px de traslación vertical, escala 0.97→1 y opacidad. Las del historial
  /// no se animan.
  final bool animarEntrada;

  @override
  Widget build(BuildContext context) {
    final burbuja = _contenido();
    if (!animarEntrada) return burbuja;
    final sinMovimiento = _sinMovimiento(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: sinMovimiento ? Motion.fast : Motion.base,
      curve: Motion.easeOut,
      child: burbuja,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: sinMovimiento
            ? child
            : Transform.translate(
                offset: Offset(0, 8 * (1 - t)),
                child: Transform.scale(
                  scale: 0.97 + 0.03 * t,
                  alignment: sentByMe
                      ? Alignment.bottomRight
                      : Alignment.bottomLeft,
                  child: child,
                ),
              ),
      ),
    );
  }

  Widget _contenido() => LayoutBuilder(
    builder: (context, caja) => Align(
      alignment: sentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: caja.maxWidth * .8),
        child: Column(
          crossAxisAlignment: sentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sentByMe ? AppColors.ink : AppColors.surface,
                border: sentByMe ? null : Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppRadii.panel),
              ),
              child: Text(
                message,
                style: AppText.body.copyWith(
                  color: sentByMe ? AppColors.white : AppColors.text,
                ),
              ),
            ),
            if (receipt != null) ...[
              const SizedBox(height: 4),
              Text(receipt!, style: AppText.meta),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Compositor del chat: panel flotante, la única sombra permitida, con
/// etiqueta visible ("Mensaje para Lucía").
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.label,
    required this.onSend,
    this.sending = false,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(color: AppColors.border),
      boxShadow: const [AppShadows.floating],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                style: AppText.field,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(hintText: 'Escribir mensaje'),
              ),
            ),
            const SizedBox(width: AppSpacing.group),
            sending
                ? const SizedBox.square(
                    dimension: AppSpacing.tap,
                    child: Center(child: AppSpinner()),
                  )
                : AppIconButton(
                    icon: Icons.send_outlined,
                    tooltip: 'Enviar mensaje',
                    onPressed: onSend,
                  ),
          ],
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Barra inferior
// ---------------------------------------------------------------------------

class BottomNavItem {
  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// 5 pestañas, `surface`, borde superior y sin sombra. La activa lleva texto
/// 600 y una píldora neutra de 48×28 tras el icono.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.unreadMessages = 0,
    this.chatIndex = 3,
  }) : assert(items.length == 5);

  final List<BottomNavItem> items;
  final int selectedIndex;
  final int unreadMessages;
  final int chatIndex;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.border)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: LayoutBuilder(
          builder: (context, caja) {
            final celda = caja.maxWidth / items.length;
            return Stack(
              children: [
                // La píldora se desliza al nuevo icono (transform, no posición).
                // El contenido de la pestaña no se anima.
                Positioned(
                  left: 0,
                  top: 0,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: selectedIndex.toDouble()),
                    duration: _sinMovimiento(context)
                        ? Duration.zero
                        : Motion.base,
                    curve: Motion.easeInOut,
                    builder: (context, indice, _) => Transform.translate(
                      offset: Offset((indice + .5) * celda - 24, 0),
                      child: Container(
                        width: 48,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.active,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: _BottomNavButton(
                          item: items[i],
                          selected: i == selectedIndex,
                          unread: i == chatIndex ? unreadMessages : 0,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.unread,
  });

  final BottomNavItem item;
  final bool selected;
  final int unread;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: item.label,
    excludeSemantics: true,
    child: InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
            width: 48,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(item.icon, size: 20, color: AppColors.text),
                if (unread > 0)
                  Positioned(
                    top: -4,
                    right: -2,
                    child: _Contador(
                      count: unread,
                      size: 20,
                      bordeColor: AppColors.surface,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.metaStrong.copyWith(
              color: AppColors.text,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}
