# Run the SILVAMANG AI Flutter app on a connected Android phone.
# The phone must have USB debugging enabled.
# Choose the Android phone if Flutter asks.

cd C:\laragon\www\SilvaMang-AI\silvamang_mobile
& C:\flutter\bin\flutter.bat devices
& C:\flutter\bin\flutter.bat clean
& C:\flutter\bin\flutter.bat pub get
& C:\flutter\bin\flutter.bat run
