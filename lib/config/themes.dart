// Named themes. All apps (Flutter + CLI) share the same palette IDs so
// switching in one syncs the other.

import 'package:flutter/material.dart';

class AppPalette {
  final String id;
  final String name;
  final Color base;
  final Color surface;
  final Color overlay;
  final Color text;
  final Color muted;
  final Color primary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;

  const AppPalette({
    required this.id,
    required this.name,
    required this.base,
    required this.surface,
    required this.overlay,
    required this.text,
    required this.muted,
    required this.primary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
  });
}

const kDoomOne = AppPalette(
  id: 'doom-one',
  name: 'Doom One',
  base: Color(0xFF282C34),
  surface: Color(0xFF21242B),
  overlay: Color(0xFF3F444A),
  text: Color(0xFFBBC2CF),
  muted: Color(0xFF5B6268),
  primary: Color(0xFF51AFEF),
  accent: Color(0xFFC678DD),
  success: Color(0xFF98BE65),
  warning: Color(0xFFECBE7B),
  error: Color(0xFFFF6C6B),
);

const kCatppuccinMocha = AppPalette(
  id: 'catppuccin-mocha',
  name: 'Catppuccin Mocha',
  base: Color(0xFF1E1E2E),
  surface: Color(0xFF181825),
  overlay: Color(0xFF313244),
  text: Color(0xFFCDD6F4),
  muted: Color(0xFF7F849C),
  primary: Color(0xFF89B4FA),
  accent: Color(0xFFCBA6F7),
  success: Color(0xFFA6E3A1),
  warning: Color(0xFFF9E2AF),
  error: Color(0xFFF38BA8),
);

const kNord = AppPalette(
  id: 'nord',
  name: 'Nord',
  base: Color(0xFF2E3440),
  surface: Color(0xFF3B4252),
  overlay: Color(0xFF4C566A),
  text: Color(0xFFECEFF4),
  muted: Color(0xFF616E88),
  primary: Color(0xFF88C0D0),
  accent: Color(0xFFB48EAD),
  success: Color(0xFFA3BE8C),
  warning: Color(0xFFEBCB8B),
  error: Color(0xFFBF616A),
);

const kGruvbox = AppPalette(
  id: 'gruvbox',
  name: 'Gruvbox',
  base: Color(0xFF282828),
  surface: Color(0xFF1D2021),
  overlay: Color(0xFF3C3836),
  text: Color(0xFFEBDBB2),
  muted: Color(0xFF928374),
  primary: Color(0xFF83A598),
  accent: Color(0xFFD3869B),
  success: Color(0xFFB8BB26),
  warning: Color(0xFFFABD2F),
  error: Color(0xFFFB4934),
);

const kTokyoNight = AppPalette(
  id: 'tokyo-night',
  name: 'Tokyo Night',
  base: Color(0xFF1A1B26),
  surface: Color(0xFF16161E),
  overlay: Color(0xFF292E42),
  text: Color(0xFFC0CAF5),
  muted: Color(0xFF565F89),
  primary: Color(0xFF7AA2F7),
  accent: Color(0xFFBB9AF7),
  success: Color(0xFF9ECE6A),
  warning: Color(0xFFE0AF68),
  error: Color(0xFFF7768E),
);

const kRosePine = AppPalette(
  id: 'rose-pine',
  name: 'Rosé Pine',
  base: Color(0xFF191724),
  surface: Color(0xFF1F1D2E),
  overlay: Color(0xFF26233A),
  text: Color(0xFFE0DEF4),
  muted: Color(0xFF6E6A86),
  primary: Color(0xFF9CCFD8),
  accent: Color(0xFFC4A7E7),
  success: Color(0xFF31748F),
  warning: Color(0xFFF6C177),
  error: Color(0xFFEB6F92),
);

const kAllPalettes = <AppPalette>[
  kDoomOne,
  kCatppuccinMocha,
  kNord,
  kGruvbox,
  kTokyoNight,
  kRosePine,
];

AppPalette paletteById(String id) =>
    kAllPalettes.firstWhere((p) => p.id == id, orElse: () => kDoomOne);
