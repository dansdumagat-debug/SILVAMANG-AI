import argparse
from pathlib import Path

import torch
from PIL import Image

try:
    from .config import DEFAULT_IMAGE_SIZE, MODEL_OUTPUT_PATH
    from .model import BaselineCNN
    from .train_cnn_baseline import build_transforms
    from .utils import get_device
except ImportError:
    from config import DEFAULT_IMAGE_SIZE, MODEL_OUTPUT_PATH
    from model import BaselineCNN
    from train_cnn_baseline import build_transforms
    from utils import get_device


def predict(image_path, top_k):
    if not MODEL_OUTPUT_PATH.exists():
        print("Model file not found. Train the baseline CNN first.")
        return

    image_file = Path(image_path)
    if not image_file.exists():
        print(f"Image file not found: {image_file}")
        return

    device = get_device()
    checkpoint = torch.load(MODEL_OUTPUT_PATH, map_location=device)
    classes = checkpoint["classes"]
    image_size = checkpoint.get("image_size", DEFAULT_IMAGE_SIZE)

    model = BaselineCNN(num_classes=len(classes)).to(device)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    transform = build_transforms(image_size)
    image = Image.open(image_file).convert("RGB")
    input_tensor = transform(image).unsqueeze(0).to(device)

    with torch.no_grad():
        outputs = model(input_tensor)
        probabilities = torch.softmax(outputs, dim=1)
        scores, indices = probabilities.topk(min(top_k, len(classes)), dim=1)

    for rank, (score, index) in enumerate(zip(scores[0], indices[0]), start=1):
        print(f"{rank}. {classes[index.item()]} - confidence: {score.item():.4f}")


def main():
    parser = argparse.ArgumentParser(description="Predict mangrove species with the baseline CNN.")
    parser.add_argument("--image", required=True, help="Path to an image file.")
    parser.add_argument("--top-k", type=int, default=3, help="Number of predictions to print.")
    args = parser.parse_args()

    predict(args.image, args.top_k)


if __name__ == "__main__":
    main()
