import argparse
import time

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from tqdm import tqdm

try:
    from .config import (
        DEFAULT_BATCH_SIZE,
        DEFAULT_EPOCHS,
        DEFAULT_IMAGE_SIZE,
        DEFAULT_LEARNING_RATE,
        MODEL_OUTPUT_PATH,
        PROCESSED_DATASET_PATH,
        RANDOM_SEED,
        REPORTS_OUTPUT_PATH,
    )
    from .model import BaselineCNN
    from .utils import count_images_by_split, ensure_dir, get_device, save_json, set_seed
except ImportError:
    from config import (
        DEFAULT_BATCH_SIZE,
        DEFAULT_EPOCHS,
        DEFAULT_IMAGE_SIZE,
        DEFAULT_LEARNING_RATE,
        MODEL_OUTPUT_PATH,
        PROCESSED_DATASET_PATH,
        RANDOM_SEED,
        REPORTS_OUTPUT_PATH,
    )
    from model import BaselineCNN
    from utils import count_images_by_split, ensure_dir, get_device, save_json, set_seed


def build_transforms(image_size):
    return transforms.Compose(
        [
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5]),
        ]
    )


def run_epoch(model, dataloader, criterion, optimizer, device, training=True):
    model.train(training)
    running_loss = 0.0
    correct = 0
    total = 0

    with torch.set_grad_enabled(training):
        for images, labels in tqdm(dataloader, leave=False):
            images = images.to(device)
            labels = labels.to(device)

            if training:
                optimizer.zero_grad()

            outputs = model(images)
            loss = criterion(outputs, labels)

            if training:
                loss.backward()
                optimizer.step()

            running_loss += loss.item() * images.size(0)
            _, predicted = outputs.max(1)
            total += labels.size(0)
            correct += predicted.eq(labels).sum().item()

    return {
        "loss": running_loss / max(total, 1),
        "accuracy": correct / max(total, 1),
    }


def main():
    parser = argparse.ArgumentParser(description="Train SILVAMANG AI baseline CNN classifier.")
    parser.add_argument("--epochs", type=int, default=DEFAULT_EPOCHS)
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE)
    parser.add_argument("--learning-rate", type=float, default=DEFAULT_LEARNING_RATE)
    parser.add_argument("--image-size", type=int, default=DEFAULT_IMAGE_SIZE)
    args = parser.parse_args()

    counts = count_images_by_split(PROCESSED_DATASET_PATH)
    if counts.get("train", 0) == 0:
        print("No training images found. Add images and run dataset_split.py --apply first.")
        return

    set_seed(RANDOM_SEED)
    ensure_dir(MODEL_OUTPUT_PATH.parent)
    ensure_dir(REPORTS_OUTPUT_PATH)

    transform = build_transforms(args.image_size)
    train_dataset = datasets.ImageFolder(PROCESSED_DATASET_PATH / "train", transform=transform)
    val_dataset = datasets.ImageFolder(PROCESSED_DATASET_PATH / "val", transform=transform)

    train_loader = DataLoader(train_dataset, batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(val_dataset, batch_size=args.batch_size, shuffle=False)

    device = get_device()
    model = BaselineCNN(num_classes=len(train_dataset.classes)).to(device)
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.parameters(), lr=args.learning_rate)

    history = {
        "classes": train_dataset.classes,
        "epochs": [],
        "started_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
    best_val_accuracy = 0.0

    for epoch in range(args.epochs):
        print(f"Epoch {epoch + 1}/{args.epochs}")
        train_metrics = run_epoch(model, train_loader, criterion, optimizer, device, training=True)
        val_metrics = run_epoch(model, val_loader, criterion, optimizer, device, training=False)

        history["epochs"].append(
            {
                "epoch": epoch + 1,
                "train_loss": train_metrics["loss"],
                "train_accuracy": train_metrics["accuracy"],
                "val_loss": val_metrics["loss"],
                "val_accuracy": val_metrics["accuracy"],
            }
        )

        if val_metrics["accuracy"] >= best_val_accuracy:
            best_val_accuracy = val_metrics["accuracy"]
            torch.save(
                {
                    "model_state_dict": model.state_dict(),
                    "classes": train_dataset.classes,
                    "image_size": args.image_size,
                    "best_val_accuracy": best_val_accuracy,
                },
                MODEL_OUTPUT_PATH,
            )

    history["best_val_accuracy"] = best_val_accuracy
    history["finished_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
    save_json(history, REPORTS_OUTPUT_PATH / "training_history.json")
    print(f"Best model saved to: {MODEL_OUTPUT_PATH}")


if __name__ == "__main__":
    main()
