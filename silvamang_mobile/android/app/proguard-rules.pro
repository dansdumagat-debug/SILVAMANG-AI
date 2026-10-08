# ONNX Runtime's native JNI code looks up Java classes and members by name.
# Preserve them in optimized release builds to prevent identification crashes.
-keep class ai.onnxruntime.** { *; }
