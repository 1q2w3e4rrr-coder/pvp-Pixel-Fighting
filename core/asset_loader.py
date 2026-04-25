import pygame
from typing import Dict, Tuple

_image_cache: Dict[Tuple[str, bool], pygame.Surface] = {}
_scaled_cache: Dict[Tuple[str, bool, int, int], pygame.Surface] = {}


def load_image(path: str, alpha: bool = True) -> pygame.Surface:
    key = (path, alpha)

    if key in _image_cache:
        return _image_cache[key]

    img = pygame.image.load(path)
    img = img.convert_alpha() if alpha else img.convert()

    _image_cache[key] = img
    return img


def load_scaled_image(path: str, size, alpha=True):
    w, h = size
    key = (path, alpha, w, h)

    if key in _scaled_cache:
        return _scaled_cache[key]

    img = load_image(path, alpha)
    img = pygame.transform.scale(img, size)

    _scaled_cache[key] = img
    return img


def clear_asset_cache():
    _image_cache.clear()
    _scaled_cache.clear()