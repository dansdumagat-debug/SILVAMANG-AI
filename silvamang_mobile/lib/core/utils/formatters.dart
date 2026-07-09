import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  static String percent(double value) => '${value.toStringAsFixed(1)}%';
  static String meters(double value) => '${value.toStringAsFixed(1)} m';
  static String date(DateTime value) => DateFormat('MMM d, yyyy').format(value);
}
