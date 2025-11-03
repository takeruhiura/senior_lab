"""
Simple FPGA Integration Example
Shows how to integrate license plate detection into your FPGA workflow
"""

from ultralytics import YOLO
import cv2
import numpy as np
import time


class FPGALicensePlateDetector:
    """
    Simple wrapper for FPGA integration
    Designed for minimal latency and easy integration
    """
    
    def __init__(self, model_path="best.pt", img_size=320, conf=0.2):
        """
        Initialize detector with FPGA-optimized settings
        
        Args:
            model_path: Path to model (can be .pt or .onnx)
            img_size: Input size (320 recommended for real-time)
            conf: Confidence threshold
        """
        self.model = YOLO(model_path)
        self.img_size = img_size
        self.conf = conf
        
    def detect_frame(self, frame):
        """
        Detect license plates in a single frame
        Optimized for real-time processing
        
        Args:
            frame: numpy array (BGR image from cv2)
            
        Returns:
            List of detections: [(x1, y1, x2, y2, confidence), ...]
        """
        results = self.model(
            frame,
            imgsz=self.img_size,
            conf=self.conf,
            verbose=False
        )
        
        detections = []
        for result in results:
            for box in result.boxes:
                x1, y1, x2, y2 = map(int, box.xyxy[0])
                conf = float(box.conf[0])
                detections.append((x1, y1, x2, y2, conf))
        
        return detections
    
    def process_stream(self, video_source=0, callback=None):
        """
        Process video stream (for FPGA integration)
        
        Args:
            video_source: Camera index or video path
            callback: Function to call with each detection
                     callback(frame, detections, fps)
        """
        cap = cv2.VideoCapture(video_source)
        
        if not cap.isOpened():
            raise ValueError(f"Cannot open video source: {video_source}")
        
        frame_times = []
        
        try:
            while True:
                ret, frame = cap.read()
                if not ret:
                    break
                
                # Detect
                start_time = time.time()
                detections = self.detect_frame(frame)
                inference_time = time.time() - start_time
                
                # Calculate FPS
                frame_times.append(inference_time)
                if len(frame_times) > 30:
                    frame_times.pop(0)
                fps = 1.0 / np.mean(frame_times)
                
                # Call user callback
                if callback:
                    callback(frame, detections, fps)
                
                # Default visualization
                else:
                    for (x1, y1, x2, y2, conf) in detections:
                        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
                        cv2.putText(frame, f"{conf:.2f}", (x1, y1-10),
                                  cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
                    
                    cv2.putText(frame, f"FPS: {fps:.1f}", (10, 30),
                              cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)
                    cv2.imshow('Detection', frame)
                    
                    if cv2.waitKey(1) & 0xFF == ord('q'):
                        break
        
        finally:
            cap.release()
            cv2.destroyAllWindows()


# ============================================================================
# EXAMPLE 1: Basic Detection
# ============================================================================

def example1_basic():
    """Simple detection on an image"""
    print("Example 1: Basic Detection")
    print("-" * 50)
    
    detector = FPGALicensePlateDetector(img_size=320)
    
    # Load image
    frame = cv2.imread("coloradoplate.jpg")
    
    # Detect
    detections = detector.detect_frame(frame)
    
    print(f"Found {len(detections)} plate(s)")
    for i, (x1, y1, x2, y2, conf) in enumerate(detections):
        print(f"  Plate {i+1}: confidence={conf:.3f}, bbox=({x1},{y1},{x2},{y2})")
    
    # Visualize
    for (x1, y1, x2, y2, conf) in detections:
        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
    
    cv2.imwrite("fpga_output.jpg", frame)
    print("Saved: fpga_output.jpg\n")


# ============================================================================
# EXAMPLE 2: Real-Time Stream with Custom Callback
# ============================================================================

def example2_stream_callback():
    """Real-time processing with custom callback"""
    print("Example 2: Real-Time Stream with Callback")
    print("-" * 50)
    
    detector = FPGALicensePlateDetector(img_size=320)
    
    # Custom callback for FPGA integration
    def my_fpga_callback(frame, detections, fps):
        """
        This function is called for each frame
        You can send data to FPGA here
        """
        # Example: Send detection data to FPGA
        for (x1, y1, x2, y2, conf) in detections:
            # Send to FPGA: coordinates and confidence
            # fpga.send_detection(x1, y1, x2, y2, conf)
            
            # Draw for visualization
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            label = f"Plate {conf:.2f}"
            cv2.putText(frame, label, (x1, y1-10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
        
        # Display FPS
        cv2.putText(frame, f"FPS: {fps:.1f}", (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 255), 2)
        
        cv2.imshow('FPGA Stream', frame)
        
        # Press 'q' to quit
        if cv2.waitKey(1) & 0xFF == ord('q'):
            return False
    
    # Process stream
    print("Starting stream (press 'q' to quit)...")
    detector.process_stream(video_source=0, callback=my_fpga_callback)


# ============================================================================
# EXAMPLE 3: Batch Processing (Multiple Images)
# ============================================================================

def example3_batch():
    """Process multiple images efficiently"""
    print("Example 3: Batch Processing")
    print("-" * 50)
    
    detector = FPGALicensePlateDetector(img_size=320)
    
    images = ["coloradoplate.jpg", "example1.jpg"]
    
    total_time = 0
    total_detections = 0
    
    for img_path in images:
        frame = cv2.imread(img_path)
        if frame is None:
            print(f"⚠️  Could not read: {img_path}")
            continue
        
        start = time.time()
        detections = detector.detect_frame(frame)
        elapsed = time.time() - start
        
        total_time += elapsed
        total_detections += len(detections)
        
        print(f"✓ {img_path}: {len(detections)} plate(s) in {elapsed*1000:.1f}ms")
    
    print(f"\nTotal: {total_detections} plates in {total_time:.3f}s")
    print(f"Average: {total_time/len(images)*1000:.1f}ms per image")
    print(f"Throughput: {len(images)/total_time:.1f} images/sec\n")


# ============================================================================
# EXAMPLE 4: Coordinates Extraction (for FPGA)
# ============================================================================

def example4_coordinates():
    """Extract plate coordinates for FPGA processing"""
    print("Example 4: Coordinate Extraction for FPGA")
    print("-" * 50)
    
    detector = FPGALicensePlateDetector(img_size=320)
    frame = cv2.imread("coloradoplate.jpg")
    
    detections = detector.detect_frame(frame)
    
    # Format for FPGA transmission
    print("Detection data for FPGA:")
    print("Format: [x1, y1, x2, y2, confidence]")
    print("-" * 50)
    
    for i, (x1, y1, x2, y2, conf) in enumerate(detections):
        # Create data packet
        data_packet = {
            'plate_id': i,
            'bbox': [x1, y1, x2, y2],
            'confidence': conf,
            'width': x2 - x1,
            'height': y2 - y1,
            'center': [(x1 + x2) // 2, (y1 + y2) // 2]
        }
        
        print(f"\nPlate {i}:")
        for key, value in data_packet.items():
            print(f"  {key}: {value}")
        
        # Extract plate region
        plate_crop = frame[y1:y2, x1:x2]
        
        # Could send this to FPGA for further processing
        # fpga.send_image(plate_crop)
        # fpga.send_metadata(data_packet)


# ============================================================================
# MAIN: Run Examples
# ============================================================================

if __name__ == "__main__":
    print("\n" + "="*50)
    print("FPGA License Plate Detection Integration")
    print("="*50 + "\n")
    
    # Run examples
    example1_basic()
    example3_batch()
    example4_coordinates()
    
    # Uncomment to test real-time stream
    # example2_stream_callback()
    
    print("\n" + "="*50)
    print("Integration Examples Complete!")
    print("="*50)
    print("\nNext Steps:")
    print("1. Modify callbacks to send data to your FPGA")
    print("2. Integrate with your FPGA communication protocol")
    print("3. Use exported ONNX model for FPGA hardware acceleration")
    print("\nFor FPGA deployment:")
    print("  python3 detect.py --mode export --export-format onnx --img-size 320")

