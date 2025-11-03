# Fast License Plate Detection for FPGA Processing

Optimized YOLOv8-based license plate detector designed for real-time FPGA deployment.

## Features

✅ **Fast Detection** - Optimized for real-time processing  
✅ **Multiple Modes** - Image, video, webcam, benchmark  
✅ **FPGA Export** - ONNX, OpenVINO, TFLite, TensorRT  
✅ **Real-time FPS** - Live performance metrics  
✅ **Minimal Dependencies** - Only essential libraries  

## Quick Start

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Basic Usage

**Detect on a single image:**
```bash
python detect.py --mode image --source coloradoplate.jpg
```

**Real-time webcam detection:**
```bash
python detect.py --mode webcam --source 0
```

**Process video file:**
```bash
python detect.py --mode video --source input.mp4 --save-video
```

**Benchmark performance:**
```bash
python detect.py --mode benchmark --source coloradoplate.jpg
```

**Export for FPGA (ONNX format):**
```bash
python detect.py --mode export --export-format onnx
```

## Command-Line Options

| Option | Default | Description |
|--------|---------|-------------|
| `--mode` | `image` | Mode: `image`, `video`, `webcam`, `export`, `benchmark` |
| `--source` | `coloradoplate.jpg` | Input image/video path or webcam index |
| `--model` | `best.pt` | Path to YOLOv8 model |
| `--conf` | `0.25` | Confidence threshold (0.0-1.0) |
| `--img-size` | `640` | Input size (smaller = faster, e.g., 320, 416, 640) |
| `--save-dir` | `detected_plates` | Output directory |
| `--save-video` | - | Save output video (flag) |
| `--output` | `output.mp4` | Output video path |
| `--export-format` | `onnx` | Export format: `onnx`, `openvino`, `tflite`, `engine` |

## Performance Optimization Tips

### For Maximum Speed:
```bash
# Use smaller input size
python detect.py --mode video --img-size 416 --source 0

# Lower confidence threshold for more detections
python detect.py --mode image --conf 0.15 --source test.jpg

# Benchmark to find optimal settings
python detect.py --mode benchmark --img-size 320
```

### FPGA Deployment:

1. **Export to ONNX** (most compatible):
```bash
python detect.py --mode export --export-format onnx --img-size 416
```

2. **Export to OpenVINO** (Intel FPGAs):
```bash
python detect.py --mode export --export-format openvino
```

3. **Export to TensorRT** (NVIDIA):
```bash
python detect.py --mode export --export-format engine
```

## Expected Performance

| Image Size | GPU (RTX 3060) | CPU (i7) | FPGA Target |
|------------|----------------|----------|-------------|
| 320x320 | ~150 FPS | ~30 FPS | ~60-120 FPS |
| 416x416 | ~120 FPS | ~20 FPS | ~40-80 FPS |
| 640x640 | ~80 FPS | ~10 FPS | ~20-40 FPS |

*FPGA performance depends on hardware (Xilinx Zynq, Intel Cyclone, etc.)*

## Output Files

**Image Mode:**
- `detected_plates/plate_0_0.jpg` - Cropped license plate
- `detected_plates/annotated_0.jpg` - Image with bounding boxes

**Video Mode:**
- Live preview window with FPS counter
- Optional: Saved output video

**Export Mode:**
- `best.onnx` - Exported model file
- Model ready for FPGA deployment

## Troubleshooting

**Issue: Slow detection**
- Reduce `--img-size` to 320 or 416
- Ensure you're using a GPU-enabled PyTorch installation

**Issue: No detections**
- Lower `--conf` threshold (try 0.15 or 0.20)
- Verify model file `best.pt` is in the correct location

**Issue: Export fails**
- Install additional dependencies: `pip install onnx onnxsim`
- For OpenVINO: `pip install openvino-dev`

## Integration with FPGA

The exported ONNX model can be deployed on:
- **Xilinx Zynq UltraScale+** - Use Vitis AI
- **Intel Cyclone/Arria** - Use OpenVINO toolkit
- **NVIDIA Jetson** - Use TensorRT

Typical FPGA workflow:
1. Export model to ONNX
2. Quantize model (INT8 for faster inference)
3. Compile for target FPGA
4. Deploy with hardware acceleration

## License
MIT License - Free for commercial and academic use

