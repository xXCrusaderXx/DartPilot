import '../board/scoring.dart';

/// A field typed on a keyboard, as on a desktop or a TV box beside the board
typedef TypedField = ({Ring ring, int sector});

/// Darts typed on a keyboard: an optional S, D or T, then the number. A number that cannot go on, such as 5 or 17,
/// counts at once; 1 and 2 wait for a second digit or Enter. B is the bull, 25 the outer bull (D25 the bull), and M,
/// X or 0 a miss. Plain Dart, so the rules are tested without a screen.
class KeyEntry {
  Ring _modifier = Ring.innerSingle;
  String _digits = '';

  /// What is typed so far, such as "T1", or empty
  String get pending => _digits.isEmpty && _modifier == Ring.innerSingle ? '' : '${_prefix(_modifier)}$_digits';

  static String _prefix(Ring ring) => switch (ring) {
    Ring.double => 'D',
    Ring.triple => 'T',
    _ => '',
  };

  /// Forgets what is typed; true when there was something
  bool clear() {
    final had = pending.isNotEmpty;
    _modifier = Ring.innerSingle;
    _digits = '';
    return had;
  }

  /// Ends the number typed so far, as Enter does: the field, or null when no number was typed
  TypedField? enter() {
    if (_digits.isEmpty) return null;
    final field = _field(int.parse(_digits));
    clear();
    return field;
  }

  /// Takes one typed character: the field when it completes a dart, else null
  TypedField? type(String character) {
    final c = character.toLowerCase();
    switch (c) {
      case 's' || 'd' || 't':
        // A number still open counts before the next dart's modifier
        final open = enter();
        _modifier = switch (c) {
          'd' => Ring.double,
          't' => Ring.triple,
          _ => Ring.innerSingle,
        };
        return open;
      case 'b':
        clear();
        return (ring: Ring.innerBull, sector: 20);
      case 'm' || 'x':
        clear();
        return (ring: Ring.miss, sector: 20);
    }
    if (c.length != 1 || !'0123456789'.contains(c)) return null;
    if (_digits.isEmpty && c == '0') {
      clear();
      return (ring: Ring.miss, sector: 20);
    }
    _digits += c;
    final n = int.parse(_digits);
    if (_digits.length == 1 && n >= 3) return enter();
    if (_digits.length == 2) {
      final field = n <= 20 || n == 25 ? _field(n) : null;
      clear();
      return field;
    }
    return null;
  }

  TypedField? _field(int n) {
    if (n == 25) {
      return switch (_modifier) {
        Ring.innerSingle => (ring: Ring.outerBull, sector: 20),
        Ring.double => (ring: Ring.innerBull, sector: 20),
        _ => null,
      };
    }
    if (n < 1 || n > 20) return null;
    return (ring: _modifier, sector: n);
  }
}
