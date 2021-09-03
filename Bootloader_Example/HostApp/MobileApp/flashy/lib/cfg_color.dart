//palette.dart
import 'package:flutter/material.dart';
class Palette {
  static const MaterialColor kToDark = const MaterialColor(
    0xff077326, // 0% comes in here, this will be color picked if no shade is selected when defining a Color property which doesn’t require a swatch.
    const <int, Color>{
      50: const Color(0xff066822 ),//10%
      100: const Color(0xff065c1e),//20%
      200: const Color(0xff05511b),//30%
      300: const Color(0xff044517),//40%
      400: const Color(0xff043a13),//50%
      500: const Color(0xff032e0f),//60%
      600: const Color(0xff02220b),//70%
      700: const Color(0xff011708),//80%
      800: const Color(0xff010b04),//90%
      900: const Color(0xff000000),//100%
    },
  );
} // you can define define int 500 as the default shade and add your lighter tints above and darker tints below.
