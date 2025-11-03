from ultralytics import YOLO
import easyocr
import cv2
import re
import os

# --- Setup ---
model = YOLO("best.pt")  # your YOLOv8 model
reader = easyocr.Reader(['en'])

# --- Input images ---
source = "example1.jpg"      # original image
sobel_source = "sobel.jpg"   # Sobel-filtered version

results = model(source)
os.makedirs("detected_plates", exist_ok=True)

# --- Words to ignore (state names, slogans, etc.) ---
ignore_words = [
    "newyork", "california", "texas", "florida", "empire", "state",
    "garden", "the", "sunshine", "golden", "usa"
]

# --- Function to check plate-like text ---
def is_plate_pattern(text):
    """
    True if text looks like a plate number:
    contains both letters & digits, length 4–10
    """
    return bool(re.search(r"^(?=.*[A-Z])(?=.*\d)[A-Z0-9-]{4,10}$", text))

# --- Process YOLO results ---
for i, result in enumerate(results):
    image = result.orig_img.copy()
    sobel_image = cv2.imread(sobel_source)

    for j, box in enumerate(result.boxes):
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        crop = sobel_image[y1:y2, x1:x2]
        cv2.imwrite(f"detected_plates/sobel_crop_{i}_{j}.jpg", crop)

        # OCR step
        texts = reader.readtext(crop, detail=0)
        print("🔍 OCR raw results:", texts)

        candidates = []
        for t in texts:
            clean = t.replace(" ", "").upper()
            if clean.lower() not in ignore_words and is_plate_pattern(clean):
                candidates.append(clean)

        if candidates:
            plate_number = max(candidates, key=len)
            print(f"✅ Detected license plate: {plate_number}")
        else:
            print("⚠️ No valid plate number found.")

        # Draw detection and result
        cv2.rectangle(image, (x1, y1), (x2, y2), (0, 255, 0), 2)
        if candidates:
            cv2.putText(
                image,
                plate_number,
                (x1, y1 - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.9,
                (36, 255, 12),
                2,
            )

    cv2.imwrite(f"detected_plates/annotated_{i}.jpg", image)
