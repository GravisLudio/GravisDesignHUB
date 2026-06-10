/// Formats a numeric value into Colombian Pesos (COP) style.
///
/// Example:
///   50000.0 -> '$ 50.000 COP'
///   120500.0 -> '$ 120.500 COP'
String formatCOP(double value) {
  final int val = value.round();
  final String str = val.abs().toString();
  final StringBuffer sb = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) {
      sb.write('.');
    }
    sb.write(str[i]);
    count++;
  }
  final String formatted = sb.toString().split('').reversed.join();
  return '${value < 0 ? '-' : ''}\$ $formatted COP';
}
