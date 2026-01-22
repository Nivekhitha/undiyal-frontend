import 'package:flutter/cupertino.dart';

class ShineEffect extends StatefulWidget {
  final Widget child;
  final bool animate;
  final Duration duration;

  const ShineEffect({
    super.key,
    required this.child,
    this.animate = true,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ShineEffect> createState() => _ShineEffectState();
}

class _ShineEffectState extends State<ShineEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.animate) {
      _controller.forward();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              stops: [
                0.0,
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
                1.0,
              ],
              colors: [
                CupertinoColors.transparent,
                CupertinoColors.transparent,
                CupertinoColors.white.withOpacity(0.3),
                CupertinoColors.transparent,
                CupertinoColors.transparent,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}
