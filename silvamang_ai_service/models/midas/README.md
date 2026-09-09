# MiDaS Depth Model

Place a TorchScript MiDaS/depth model here:

```text
midas_torchscript.pt
```

Metric height and canopy width still require a real scale source, such as phone depth/ARCore, known camera-to-tree distance, or a calibrated reference object. The service must not invent meter measurements from an uncalibrated image.
