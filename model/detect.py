import argparse
import os
import cv2
import torch
import easyocr
import re
from ultralytics import YOLO

# ============================================================
# Helper functions
# ============================================================

def clean_ocr_results(ocr_results):
    """
    Cleans and filters raw EasyOCR text results.
    Removes non-plate text like '2021', 'California', etc.
    """
    cleaned_results = []

    for text in ocr_results:
        cleaned_text = text.strip().upper()

        if not cleaned_text:
            continue

        # Remove common irrelevant words
        if cleaned_text in ["CALIFORNIA", "COLORADO", "USA", "STATE", "TRUCK", "TAXI"]:
            continue

        # Skip short numeric-only texts (e.g., "2021", "19")
        if cleaned_text.isdigit() and len(cleaned_text) <= 4:
            continue

        # Keep only alphanumeric characters
        cleaned_text = re.sub(r"[^A-Z0-9]", "", cleaned_text)

        # Skip if too short or too long to be a plate number
        if len(cleaned_text) < 4 or len(cleaned_text) > 8:
            continue

        # Must contain at least one letter (most plates do)
        if not re.search(r"[A-Z]", cleaned_text):
            continue

        cleaned_results.append(cleaned_text)

    return cleaned_results


def score_license_plate_text(text):
    """
    Assigns a confidence-like score based on how 'plate-like' a string looks.
    """
    score = 0

    # Base length score (typical plate length = 6–8 chars)
    if 6 <= len(text) <= 8:
        score += 1.0
    elif 4 <= len(text) < 6:
        score += 0.5
    else:
        score -= 0.5

    # Letter/number ratio scoring
    letter_count = len(re.findall(r"[A-Z]", text))
    number_count = len(re.findall(r"[0-9]", text))

    if letter_count > 0 and number_count > 0:
        score += 1.0
    elif letter_count > 0 and number_count == 0:
        score -= 0.2
    elif letter_count == 0 and number_count >= 3:
        score -= 0.5  # Pure numbers (likely year/expiration date)

    # Small bonus for alternating pattern (like ABC123 or 7XYZ999)
    if re.match(r"^[A-Z]{1,3}[0-9]{1,4}$", text) or re.match(r"^[0-9]{1,3}[A-Z]{1,4}$", text):
        score += 0.5

    return score


def select_best_plate_text(ocr_results):
    """
    Picks the best plate text from OCR results using cleaning + scoring.
    """
    cleaned = clean_ocr_results(ocr_results)
    if not cleaned:
        return None

    best = max(cleaned, key=lambda t: score_license_plate_text(t))

    # Apply normalization (fixes 1/I, O/0, etc.)
    best = normalize_plate_characters(best)

    return best

def normalize_plate_characters(text):
    """
    Fixes common OCR confusions like I<->1, O<->0, S<->5 based on context.
    """

    # Convert to list so we can modify by index
    chars = list(text)

    for i, c in enumerate(chars):
        # --- Replace I with 1 when surrounded by digits ---
        if c == "I":
            if (i > 0 and chars[i-1].isdigit()) or (i < len(chars)-1 and chars[i+1].isdigit()):
                chars[i] = "1"

        # --- Replace 1 with I when surrounded by letters ---
        elif c == "1":
            if (i > 0 and chars[i-1].isalpha()) or (i < len(chars)-1 and chars[i+1].isalpha()):
                chars[i] = "I"

        # --- Common O/0 mixups ---
        elif c == "O":
            if (i > 0 and chars[i-1].isdigit()) or (i < len(chars)-1 and chars[i+1].isdigit()):
                chars[i] = "0"
        elif c == "0":
            if (i > 0 and chars[i-1].isalpha()) or (i < len(chars)-1 and chars[i+1].isalpha()):
                chars[i] = "O"

        # --- Common S/5 mixups ---
        elif c == "S":
            if (i > 0 and chars[i-1].isdigit()) or (i < len(chars)-1 and chars[i+1].isdigit()):
                chars[i] = "5"
        elif c == "5":
            if (i > 0 and chars[i-1].isalpha()) or (i < len(chars)-1 and chars[i+1].isalpha()):
                chars[i] = "S"

    return "".join(chars)

def crop_plate_center(plate_crop):
    """
    Safer crop — only trims tiny margins to keep full plate text.
    """
    h, w = plate_crop.shape[:2]
    cropped = plate_crop[int(0.05*h):int(0.95*h), int(0.03*w):int(0.97*w)]
    return cropped

# ============================================================
# License Plate Detector
# ============================================================

class LicensePlateDetector:
    def __init__(self, model_path='best.pt', device='cpu'):
        print("Loading model:", model_path)
        self.model = YOLO(model_path)
        self.device = device
        print("Initializing OCR engine...")
        self.reader = easyocr.Reader(['en'])
        print("OCR ready!\n")

    def detect_image(self, source, save_dir='runs/detect'):
        print("==================================================")
        print("IMAGE DETECTION MODE")
        print("==================================================\n")

        # Load image
        if not os.path.exists(source):
            raise FileNotFoundError(f"{source} does not exist")

        img = cv2.imread(source)
        if img is None:
            raise ValueError(f"Failed to read image {source}")

        # Run YOLOv8 detection
        results = self.model(source)
        detections = results[0].boxes.data.cpu().numpy()

        if len(detections) == 0:
            print("No license plates detected.")
            return None

        # Process each detection
        os.makedirs(save_dir, exist_ok=True)
        plates = []

        for i, det in enumerate(detections):
            x1, y1, x2, y2, conf, cls = det
            plate_crop = img[int(y1):int(y2), int(x1):int(x2)]

            if plate_crop.size == 0:
                continue

            # Optional: crop central region to ignore stickers
            plate_crop = crop_plate_center(plate_crop)

            # Run EasyOCR on cropped plate
            ocr_result = self.reader.readtext(plate_crop)
            texts = [res[1] for res in ocr_result]
            best_text = select_best_plate_text(texts)

            if best_text:
                print(f"Plate {i+1}: {best_text}")
                plates.append(best_text)
            else:
                print(f"Plate {i+1}: No valid text found.")

            # Save cropped plate image
            save_path = os.path.join(save_dir, f"plate_{i+1}.jpg")
            cv2.imwrite(save_path, plate_crop)

        print("\nDetection complete. Saved results in:", save_dir)
        return plates


# ============================================================
# Main
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="License Plate Detection with YOLOv8 + EasyOCR")
    parser.add_argument("--source", type=str, default="example1.jpg", help="Path to image")
    parser.add_argument("--model", type=str, default="best.pt", help="YOLOv8 model path")
    parser.add_argument("--save_dir", type=str, default="runs/detect", help="Directory to save results")
    args = parser.parse_args()

    detector = LicensePlateDetector(model_path=args.model)
    plates = detector.detect_image(args.source, args.save_dir)

    if plates:
        print("\nFinal Detected Plates:", plates)
    else:
        print("\nNo plates detected.")


if __name__ == "__main__":
    main()
