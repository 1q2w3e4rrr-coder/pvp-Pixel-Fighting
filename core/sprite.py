import os
import re
import pygame

from core.asset_loader import load_image

try:
    import numpy as np
except ImportError:
    np = None


_pair_sheet_cache = {}


def _infer_mask_path(color_path: str) -> str:
    # 行走动画2.jpg -> 行走动画1.jpg
    # 攻击12.jpg -> 攻击11.jpg
    # 技能22.jpg -> 技能21.jpg
    return re.sub(r'2\.jpg$', '1.jpg', color_path)


def _make_alpha_from_mask(mask_surface: pygame.Surface) -> pygame.Surface:
    """
    1图通常是黑底白人形。
    我们把亮的地方变成 alpha，暗的地方透明。
    """
    mask_img = mask_surface.convert_alpha()
    w, h = mask_img.get_size()

    alpha_surface = pygame.Surface((w, h), pygame.SRCALPHA)

    if np is not None:
        rgb = pygame.surfarray.pixels3d(mask_img)
        out = pygame.surfarray.pixels3d(alpha_surface)
        a = pygame.surfarray.pixels_alpha(alpha_surface)

        luminance = rgb.max(axis=2)
        a[:, :] = luminance

        out[:, :, 0] = 255
        out[:, :, 1] = 255
        out[:, :, 2] = 255

        del rgb
        del out
        del a
        return alpha_surface

    for x in range(w):
        for y in range(h):
            r, g, b, _ = mask_img.get_at((x, y))
            lum = max(r, g, b)
            alpha_surface.set_at((x, y), (255, 255, 255, lum))

    return alpha_surface


def _compose_pair(mask_surface: pygame.Surface, color_surface: pygame.Surface) -> pygame.Surface:
    """
    用 1图 做 alpha，用 2图 做 RGB。
    """
    color = color_surface.copy().convert_alpha()
    alpha_img = _make_alpha_from_mask(mask_surface)

    if np is not None:
        rgb = pygame.surfarray.pixels3d(color)
        alpha = pygame.surfarray.pixels_alpha(color)
        alpha_src = pygame.surfarray.pixels_alpha(alpha_img)

        alpha[:, :] = alpha_src[:, :]

        del rgb
        del alpha
        del alpha_src
        return color

    w, h = color.get_size()
    for x in range(w):
        for y in range(h):
            r, g, b, _ = color.get_at((x, y))
            _, _, _, a = alpha_img.get_at((x, y))
            color.set_at((x, y), (r, g, b, a))

    return color


class SpriteSheet:
    def __init__(self, path, colorkey=None):
        self.color_path = path
        self.mask_path = _infer_mask_path(path)

        self.color_image = load_image(self.color_path, alpha=True)

        if os.path.exists(self.mask_path):
            self.mask_image = load_image(self.mask_path, alpha=True)
        else:
            self.mask_image = None

        self.image = self.color_image
        self.colorkey = colorkey

    def get(self, x, y, w, h):
        rect = pygame.Rect(x, y, w, h)

        if self.mask_image is not None:
            cache_key = (self.color_path, self.mask_path, x, y, w, h)
            if cache_key in _pair_sheet_cache:
                return _pair_sheet_cache[cache_key]

            safe_rect = rect.clip(self.color_image.get_rect())

            if self.mask_image is not None:
                safe_rect = safe_rect.clip(self.mask_image.get_rect())

            if safe_rect.width <= 0 or safe_rect.height <= 0:
                return pygame.Surface((max(1, rect.width), max(1, rect.height)), pygame.SRCALPHA)

            if self.mask_image is not None:
                mask_frame = self.mask_image.subsurface(safe_rect).copy()
                color_frame = self.color_image.subsurface(safe_rect).copy()
                # 你原本的合成逻辑继续用
            else:
                color_frame = self.color_image.subsurface(safe_rect).copy()

            frame = _compose_pair(mask_frame, color_frame)

            _pair_sheet_cache[cache_key] = frame
            return frame

        frame = self.color_image.subsurface(rect).copy()
        if self.colorkey is not None:
            frame.set_colorkey(self.colorkey)
        return frame