import pygame

from core.asset_loader import load_image, load_scaled_image
from core.scene import SceneFight


class SceneLoadingFight:

    def __init__(self, game, p1_class, p2_class, p1_name, p2_name):
        self.game = game
        self.p1_class = p1_class
        self.p2_class = p2_class
        self.p1_name = p1_name
        self.p2_name = p2_name

        self.font = pygame.font.SysFont("SimHei", 34)
        self.small_font = pygame.font.SysFont("SimHei", 24)

        self.tasks = [
            ("加载战斗背景", self.load_common_bg),
            ("加载血条资源", self.load_hp_assets),
            ("预热角色1资源", self.prewarm_p1),
            ("预热角色2资源", self.prewarm_p2),
        ]

        self.current_index = 0
        self.current_text = "准备进入战斗..."
        self.finished = False

    def load_common_bg(self):
        load_scaled_image("assets/战斗地图/background1.jpg", (1500, 800), alpha=False)

    def load_hp_assets(self):
        paths = [
            "assets/战斗地图/血条1.jpg",
            "assets/战斗地图/血条2.jpg",
            "assets/战斗地图/1血量.jpg",
            "assets/战斗地图/血条头像1左.jpg",
            "assets/战斗地图/血条头像1右.jpg",
            "assets/战斗地图/佩恩血条头像左.jpg",
            "assets/战斗地图/佩恩血条头像右.jpg",
            "assets/战斗地图/鸣人血条头像左.jpg",
            "assets/战斗地图/鸣人血条头像右.jpg",
            "assets/战斗地图/千手柱间血条头像左.jpg",
            "assets/战斗地图/千手柱间血条头像右.jpg",
        ]
        for p in paths:
            load_image(p, alpha=True)

    def prewarm_p1(self):
        # 构造一次，用来填满动画帧缓存
        self.p1_class(-9999, -9999, True)

    def prewarm_p2(self):
        self.p2_class(-9999, -9999, False)

    def handle_event(self, event):
        pass

    def update(self):
        if self.finished:
            return

        if self.current_index < len(self.tasks):
            self.current_text, fn = self.tasks[self.current_index]
            fn()
            self.current_index += 1
            return

        self.finished = True
        self.game.change_scene(
            SceneFight(
                self.game,
                self.p1_class,
                self.p2_class,
                self.p1_name,
                self.p2_name
            )
        )

    def draw(self, screen):
        screen.fill((20, 20, 20))

        title = self.font.render("Loading...", True, (255, 255, 255))
        screen.blit(title, (620, 300))

        info = self.small_font.render(self.current_text, True, (220, 220, 220))
        screen.blit(info, (560, 360))

        total = len(self.tasks)
        done = min(self.current_index, total)

        bar_x = 350
        bar_y = 430
        bar_w = 800
        bar_h = 24

        pygame.draw.rect(screen, (70, 70, 70), (bar_x, bar_y, bar_w, bar_h))
        fill_w = int(bar_w * done / total) if total > 0 else bar_w
        pygame.draw.rect(screen, (80, 180, 255), (bar_x, bar_y, fill_w, bar_h))

        percent = self.small_font.render(f"{done}/{total}", True, (255, 255, 255))
        screen.blit(percent, (725, 470))