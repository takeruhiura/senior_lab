import serial
import numpy as np
from PIL import Image

PORT   = 'COM3'        # or '/dev/ttyUSB0' on Linux
BAUD   = 115200
WIDTH  = 160
HEIGHT = 120
FRAME_SIZE = WIDTH * HEIGHT

ser = serial.Serial(PORT, BAUD, timeout=5)

print("Waiting for frame...")
data = ser.read(FRAME_SIZE)

if len(data) != FRAME_SIZE:
    print(f"Expected {FRAME_SIZE} bytes, got {len(data)}")
    exit(1)

img = np.frombuffer(data, dtype=np.uint8).reshape((HEIGHT, WIDTH))
Image.fromarray(img, mode='L').save('capture.bmp')
print("Saved capture.bmp")
