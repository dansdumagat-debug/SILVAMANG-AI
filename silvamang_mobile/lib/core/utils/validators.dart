class Validators {
  const Validators._();

  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  static String? email(String? value) {
    if (required(value) != null) return required(value);
    if (!value!.contains('@')) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}
