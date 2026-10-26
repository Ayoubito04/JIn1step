import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';

enum StatusVariant { neutral, success, warning, error }

/// Fondo común de pantalla. El contenido decide si necesita scroll.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppGradients.background),
    child: child,
  );
}

class JCard extends StatelessWidget {
  const JCard({super.key, required this.child, this.padding, this.radius});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
    decoration: BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(radius ?? AppRadii.card),
      border: Border.all(color: AppColors.cardBorder),
      boxShadow: const [AppShadows.card],
    ),
    child: child,
  );
}

class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.semanticLabel});

  final Widget icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    image: true,
    child: SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.iconTile,
          borderRadius: BorderRadius.circular(AppRadii.iconTile),
        ),
        child: Center(child: icon),
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.variant = StatusVariant.neutral,
    this.icon,
  });

  final String label;
  final StatusVariant variant;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = switch (variant) {
      StatusVariant.neutral => (
        AppColors.white,
        AppColors.fieldBorder,
        AppColors.pillText,
      ),
      StatusVariant.success => (
        AppColors.successBackground,
        AppColors.successBorder,
        AppColors.successText,
      ),
      StatusVariant.warning => (
        AppColors.warningBackground,
        AppColors.warningBorder,
        AppColors.warningText,
      ),
      StatusVariant.error => (
        AppColors.errorBackground,
        AppColors.errorBorder,
        AppColors.errorText,
      ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            IconTheme(
              data: IconThemeData(color: foreground, size: 18),
              child: icon!,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// El color debe venir de la pantalla/dato de diseño hasta confirmar los umbrales.
class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.percentage, required this.color});

  final int percentage;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    '$percentage%',
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w800,
      color: color,
    ),
  );
}

class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
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
    button: true,
    selected: selected,
    label: label,
    child: Material(
      color: selected ? AppColors.primary : AppColors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.fieldBorder,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.white : AppColors.pillText,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool loading;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: AppGradients.primary,
      borderRadius: BorderRadius.circular(AppRadii.button),
      boxShadow: const [AppShadows.primaryButton],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: AppColors.white,
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            const SnakeLoadingIndicator(),
            const SizedBox(width: 8),
            Text(
              'Iniciando sesión…',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else ...[
            if (leading != null) ...[leading!, const SizedBox(width: 8)],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Serpiente luminosa que recorre una curva mientras se completa el acceso.
class SnakeLoadingIndicator extends StatefulWidget {
  const SnakeLoadingIndicator({super.key});

  @override
  State<SnakeLoadingIndicator> createState() => _SnakeLoadingIndicatorState();
}

class _SnakeLoadingIndicatorState extends State<SnakeLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Iniciando sesión',
    child: ExcludeSemantics(
      child: SizedBox(
        width: 42,
        height: 22,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) =>
              CustomPaint(painter: _SnakePainter(progress: _controller.value)),
        ),
      ),
    ),
  );
}

class _SnakePainter extends CustomPainter {
  const _SnakePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[];
    for (var segment = 0; segment < 7; segment++) {
      final position = progress - segment * .075;
      if (position < 0) continue;
      final x = position * size.width;
      final y = size.height / 2 + math.sin(position * math.pi * 2) * 4;
      points.add(Offset(x, y));
    }

    final connector = Paint()
      ..color = AppColors.white.withValues(alpha: .62)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < points.length - 1; index++) {
      canvas.drawLine(points[index], points[index + 1], connector);
    }

    for (var index = points.length - 1; index >= 0; index--) {
      final radius = index == 0 ? 4.2 : 3.2 - index * .12;
      final paint = Paint()
        ..color = index == 0
            ? AppColors.white
            : AppColors.white.withValues(alpha: .82 - index * .08);
      canvas.drawCircle(points[index], radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.authStyle = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final bool authStyle;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      foregroundColor: authStyle ? AppColors.ink : AppColors.primaryDark,
      backgroundColor: AppColors.white,
      side: BorderSide(
        color: authStyle ? AppColors.fieldBorder : AppColors.primary,
        width: authStyle ? 1 : 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: authStyle ? AppColors.ink : AppColors.primaryDark,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.validator,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.autocorrect = true,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefix;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autocorrect;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 48,
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          autocorrect: autocorrect,
          autofillHints: autofillHints,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefix,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ),
    ],
  );
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.onHero = false});

  final double value;
  final bool onHero;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadii.progress),
    child: SizedBox(
      height: 8,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: onHero
                ? AppColors.white.withValues(alpha: .28)
                : AppColors.barTrack,
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0, 1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: onHero ? null : AppGradients.barFill,
                color: onHero ? AppColors.white : null,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: AppGradients.hero,
      borderRadius: BorderRadius.circular(AppRadii.hero),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: AppColors.white),
      child: child,
    ),
  );
}

class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.icon,
    required this.iconLabel,
    required this.title,
    required this.companyAndMode,
    required this.match,
    required this.matchColor,
    this.tags = const [],
    this.onTap,
  });

  final Widget icon;
  final String iconLabel;
  final String title;
  final String companyAndMode;
  final int match;
  final Color matchColor;
  final List<Widget> tags;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: JCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon: icon, semanticLabel: iconLabel),
                const SizedBox(width: AppSpacing.cardGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        companyAndMode,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.cardGap),
                MatchBadge(percentage: match, color: matchColor),
              ],
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.cardGap),
              Wrap(
                spacing: AppSpacing.cardGap,
                runSpacing: AppSpacing.cardGap,
                children: tags,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class OfferTag extends StatelessWidget {
  const OfferTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.primaryDark,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.initial, this.size = 46});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Avatar $initial',
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.primary,
      ),
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppColors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count, this.size = 22});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$count mensajes sin leer',
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.badge,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.sentByMe,
    this.receipt,
  });

  final String message;
  final bool sentByMe;
  final String? receipt;

  @override
  Widget build(BuildContext context) {
    final alignment = sentByMe ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadii.chatBubble),
      topRight: const Radius.circular(AppRadii.chatBubble),
      bottomLeft: Radius.circular(sentByMe ? AppRadii.chatBubble : 6),
      bottomRight: Radius.circular(sentByMe ? 6 : AppRadii.chatBubble),
    );
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 0.78 * 390),
        child: Column(
          crossAxisAlignment: sentByMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: sentByMe ? AppGradients.primary : null,
                color: sentByMe ? null : AppColors.white,
                border: sentByMe
                    ? null
                    : Border.all(color: AppColors.cardBorder),
                borderRadius: radius,
              ),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: sentByMe ? AppColors.white : AppColors.ink,
                  fontSize: 14,
                ),
              ),
            ),
            if (receipt != null) ...[
              const SizedBox(height: 4),
              Text(
                receipt!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class BottomNavItem {
  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;
}

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.unreadMessages = 0,
  }) : assert(items.length == 5);

  final List<BottomNavItem> items;
  final int selectedIndex;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
    decoration: BoxDecoration(
      color: AppColors.white,
      border: const Border(top: BorderSide(color: AppColors.cardBorder)),
      boxShadow: const [AppShadows.bottomNavigation],
    ),
    child: Row(
      children: [
        for (var index = 0; index < items.length; index++)
          Expanded(
            child: _BottomNavButton(
              item: items[index],
              selected: index == selectedIndex,
              showUnread: index == 3 && unreadMessages > 0,
              unreadMessages: unreadMessages,
            ),
          ),
      ],
    ),
  );
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.item,
    required this.selected,
    required this.showUnread,
    required this.unreadMessages,
  });

  final BottomNavItem item;
  final bool selected;
  final bool showUnread;
  final int unreadMessages;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: item.label,
    child: InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (selected)
                    Container(
                      width: 52,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  IconTheme(
                    data: IconThemeData(
                      color: selected ? AppColors.primaryDark : AppColors.muted,
                      size: 22,
                    ),
                    child: item.icon,
                  ),
                  if (showUnread)
                    Positioned(
                      top: -2,
                      right: -5,
                      child: Container(
                        width: 17,
                        height: 17,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.badge,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.badgeBorder,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '$unreadMessages',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected ? AppColors.primaryDark : AppColors.muted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
