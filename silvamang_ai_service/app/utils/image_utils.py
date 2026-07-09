async def count_uploaded_images(images: list | None) -> int:
    if images is None:
        return 0

    return len(images)
