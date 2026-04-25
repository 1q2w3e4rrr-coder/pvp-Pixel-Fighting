import pygame
from collections import deque
from core.asset_loader import load_image


def load_ui_cutout(path: str, light_threshold: int = 232, dark_threshold: int = 24) -> pygame.Surface:
    """
    删除与四角连通的近白/近黑背景。
    额外做一次边缘残渣清理，去掉 jpg 压缩留下的小白点。
    """
    src = load_image(path, alpha=True).copy().convert_alpha()
    w, h = src.get_size()

    visited = [[False] * h for _ in range(w)]
    q = deque()

    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    for cx, cy in corners:
        q.append((cx, cy))

    def is_bg_pixel(x, y):
        r, g, b, a = src.get_at((x, y))
        if a == 0:
            return False
        is_light = r >= light_threshold and g >= light_threshold and b >= light_threshold
        is_dark = r <= dark_threshold and g <= dark_threshold and b <= dark_threshold
        return is_light or is_dark

    # 8 邻域 flood fill，把角落连通背景抠掉
    neighbors8 = [
        (1, 0), (-1, 0), (0, 1), (0, -1),
        (1, 1), (1, -1), (-1, 1), (-1, -1)
    ]

    while q:
        x, y = q.popleft()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        if visited[x][y]:
            continue
        visited[x][y] = True

        if not is_bg_pixel(x, y):
            continue

        src.set_at((x, y), (255, 255, 255, 0))

        for dx, dy in neighbors8:
            q.append((x + dx, y + dy))

    # 边缘残渣清理：
    # 如果一个近白/近黑像素紧贴透明区，也把它删掉
    # 只做一轮，避免误伤血条内部高光
    to_clear = []
    for x in range(1, w - 1):
        for y in range(1, h - 1):
            r, g, b, a = src.get_at((x, y))
            if a == 0:
                continue

            is_light = r >= light_threshold and g >= light_threshold and b >= light_threshold
            is_dark = r <= dark_threshold and g <= dark_threshold and b <= dark_threshold
            if not (is_light or is_dark):
                continue

            touching_transparent = False
            for dx, dy in neighbors8:
                _, _, _, na = src.get_at((x + dx, y + dy))
                if na == 0:
                    touching_transparent = True
                    break

            if touching_transparent:
                to_clear.append((x, y))

    for x, y in to_clear:
        src.set_at((x, y), (255, 255, 255, 0))

    return src


class HPBar:

    def __init__(self, p1_name, p2_name):
        self.hp1 = load_ui_cutout("assets/战斗地图/血条1.jpg")
        self.hp2 = load_ui_cutout("assets/战斗地图/血条2.jpg")

        self.unit = load_image("assets/战斗地图/1血量.jpg", alpha=True)

        self.head_left_bg = load_ui_cutout("assets/战斗地图/血条头像1左.jpg")
        self.head_right_bg = load_ui_cutout("assets/战斗地图/血条头像1右.jpg")

        left_map = {
            "佩恩头像.jpg": "assets/战斗地图/佩恩血条头像左.jpg",
            "鸣人头像.jpg": "assets/战斗地图/鸣人血条头像左.jpg",
            "千手柱间头像.jpg": "assets/战斗地图/千手柱间血条头像左.jpg",
        }

        right_map = {
            "佩恩头像.jpg": "assets/战斗地图/佩恩血条头像右.jpg",
            "鸣人头像.jpg": "assets/战斗地图/鸣人血条头像右.jpg",
            "千手柱间头像.jpg": "assets/战斗地图/千手柱间血条头像右.jpg",
        }

        self.head_left = load_ui_cutout(left_map[p1_name])
        self.head_right = load_ui_cutout(right_map[p2_name])

        self.max_bar_value = 526

    def draw(self, screen, p1, p2):
        screen.blit(self.hp1, (0, 0))
        screen.blit(self.hp2, (0, 0))

        screen.blit(self.head_left_bg, (0, 0))
        screen.blit(self.head_right_bg, (1352, 0))

        screen.blit(self.head_left, (0, 0))
        screen.blit(self.head_right, (1352, 0))

        p1_fill = int((p1.hp / p1.max_hp) * self.max_bar_value)
        p2_fill = int((p2.hp / p2.max_hp) * self.max_bar_value)

        p1_fill = max(0, min(p1_fill, self.max_bar_value))
        p2_fill = max(0, min(p2_fill, self.max_bar_value))

        for i in range(p1_fill):
            screen.blit(self.unit, (149 + i, 45))

        for i in range(p2_fill):
            screen.blit(self.unit, (1358 - i, 45))