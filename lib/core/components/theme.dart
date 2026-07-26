import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF0B71DF);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFFC3F1D);
  static const Color gray = Color(0xFF8A8FA3);

  static const Color transparent = Colors.transparent;
}

class AppLightColors {
  static const Color border = Color(0xFFE7E9F2);
  static const Color bg = Color(0xFFFFFFFF);

  static const Color text = Color(0xFF1C1F2A);

  static const Color primarySecond = Color(0xFFA59BF4);
}

class AppDarkColors {
  static const Color border = Color(0xFF2A2F3D);
  static const Color bg = Color(0xFF0F111A);

  static const Color text = Color(0xFFF2F3F7);

  static const Color primarySecond = Color(0xFF2A244D);
}

class AppText {
  // ==== Montserrat ====
  // bold
  static const bold_24 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: "Montserrat",
  );
  static const bold_19 = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    fontFamily: "Montserrat",
  );

  // ==== MontserratAlternates ====
  // reg
  static const regular_24a = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    fontFamily: "MontserratAlternates",
  );
  static const regular_18a = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    fontFamily: "MontserratAlternates",
  );
}
