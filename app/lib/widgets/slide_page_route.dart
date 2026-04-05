import 'package:flutter/material.dart';

/// 進む（push）: 右からスライドイン。
/// 戻る（pop）: 左へスライドアウト（解答確認から次の問題へ進む動き向け）。
Route<T> slideFromRightRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final w = MediaQuery.sizeOf(context).width;
          final double dx;
          if (animation.status == AnimationStatus.reverse) {
            // pop: 中央 → 左外（先へ進むイメージ）
            dx = (animation.value - 1) * w;
          } else {
            // push: 右外 → 中央
            dx = (1 - animation.value) * w;
          }
          return Transform.translate(
            offset: Offset(dx, 0),
            child: child,
          );
        },
        child: child,
      );
    },
  );
}
