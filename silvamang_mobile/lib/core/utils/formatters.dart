import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  static DateTime philippineTime(DateTime value) =>
      value.toUtc().add(const Duration(hours: 8));
  static String dateTime(DateTime value) =>
      "${DateFormat('MMM d, yyyy h:mm a').format(philippineTime(value))} PHT";

  static String percent(double value) => '${value.toStringAsFixed(1)}%';
  static String meters(double value) => '${value.toStringAsFixed(1)} m';
  static String date(DateTime value) =>
      DateFormat('MMM d, yyyy').format(philippineTime(value));
}
