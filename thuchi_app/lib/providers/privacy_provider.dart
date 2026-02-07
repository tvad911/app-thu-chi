import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global privacy mode state — when true, all amounts show as '***'
final privacyModeProvider = StateProvider<bool>((ref) => false);
