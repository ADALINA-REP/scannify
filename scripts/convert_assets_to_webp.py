#!/usr/bin/env python3
"""Batch-converts .png, .jpg, and .jpeg files in assets/ to compressed .webp."""

from pathlib import Path
from PIL import Image

ASSETS_DIR = Path("assets")
QUALITY = 80
DELETE_ORIGINALS = True


def convert_images_to_webp(root_dir: Path) -> None:
    if not root_dir.exists():
        print(f"Directory '{root_dir}' does not exist. Skipping.")
        return

    extensions = {".png", ".jpg", ".jpeg"}
    for img_path in root_dir.rglob("*"):
        if img_path.suffix.lower() not in extensions:
            continue

        webp_path = img_path.with_suffix(".webp")
        before_bytes = img_path.stat().st_size

        with Image.open(img_path) as img:
            img.save(webp_path, format="WEBP", quality=QUALITY, method=6)

        after_bytes = webp_path.stat().st_size
        saved_kb = (before_bytes - after_bytes) / 1024
        print(f"{img_path} -> {webp_path} (saved {saved_kb:.1f} KB)")

        if DELETE_ORIGINALS:
            img_path.unlink()


if __name__ == "__main__":
    convert_images_to_webp(ASSETS_DIR)

