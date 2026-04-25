import pygame

from players.pain import PlayerPain
from players.naruto import PlayerNaruto
from players.hashirama import PlayerHashirama
from ui.loading_fight import SceneLoadingFight


class SceneSelect:

    def __init__(self, game):
        self.game = game

        self.img = pygame.image.load(
            "assets/游戏界面/chosehero.jpg"
        ).convert()

        self.frame_w = 1500
        self.frame_h = 800
        self.frame_count = self.img.get_width() // self.frame_w
        self.frame_index = 0
        self.timer = 0
        self.speed = 5

        self.names = [
            "佩恩头像.jpg",
            "鸣人头像.jpg",
            "带土头像.jpg",
            "冬狮郎头像.jpg",
            "露琪亚头像.jpg",
            "一护头像.jpg",
            "小南头像.jpg",
            "自来也头像.jpg",
            "奇拉比头像.jpg",
            "千手柱间头像.jpg",
        ]

        self.enabled = {
            "佩恩头像.jpg": True,
            "鸣人头像.jpg": True,
            "千手柱间头像.jpg": True,
        }

        self.heads = []
        self.gray = []

        for n in self.names:
            img = pygame.image.load("assets/游戏界面/" + n).convert_alpha()
            img = pygame.transform.scale(img, (80, 80))
            self.heads.append(img)

            g = img.copy()
            g.fill((100, 100, 100, 255), special_flags=pygame.BLEND_RGBA_MULT)
            self.gray.append(g)

        self.p1_box = pygame.image.load(
            "assets/游戏界面/player11.jpg"
        ).convert_alpha()

        self.p2_box = pygame.image.load(
            "assets/游戏界面/player21.jpg"
        ).convert_alpha()

        self.p1_box = pygame.transform.scale(self.p1_box, (90, 90))
        self.p2_box = pygame.transform.scale(self.p2_box, (90, 90))

        self.left_positions = [
            (150, 120),
            (150, 220),
            (150, 320),
            (150, 420),
            (150, 520),
        ]

        self.right_positions = [
            (1270, 120),
            (1270, 220),
            (1270, 320),
            (1270, 420),
            (1270, 520),
        ]

        self.positions = self.left_positions + self.right_positions

        self.p1_cursor = 0
        self.p2_cursor = 5

        self.p1_index = None
        self.p2_index = None

        self.turn = 1

        # 防止从菜单按 Enter 进入后，立刻把 Pain 默认选掉
        self.enter_lock_frames = 8

    def is_enabled(self, i):
        return self.enabled.get(self.names[i], False)

    def move_cursor(self, cursor, direction):
        row = cursor % 5
        col = 0 if cursor < 5 else 1

        for _ in range(10):
            if direction == "up":
                row = (row - 1) % 5
            elif direction == "down":
                row = (row + 1) % 5
            elif direction == "left":
                col = max(0, col - 1)
            elif direction == "right":
                col = min(1, col + 1)

            nxt = col * 5 + row
            if self.is_enabled(nxt):
                return nxt

        return cursor

    def handle_event(self, event):
        if event.type != pygame.KEYDOWN:
            return

        if self.enter_lock_frames > 0:
            if event.key == pygame.K_RETURN:
                return

        if self.turn == 1:
            if event.key in (pygame.K_w, pygame.K_UP):
                self.p1_cursor = self.move_cursor(self.p1_cursor, "up")
            elif event.key in (pygame.K_s, pygame.K_DOWN):
                self.p1_cursor = self.move_cursor(self.p1_cursor, "down")
            elif event.key in (pygame.K_a, pygame.K_LEFT):
                self.p1_cursor = self.move_cursor(self.p1_cursor, "left")
            elif event.key in (pygame.K_d, pygame.K_RIGHT):
                self.p1_cursor = self.move_cursor(self.p1_cursor, "right")
            elif event.key == pygame.K_RETURN:
                if not self.is_enabled(self.p1_cursor):
                    return
                self.p1_index = self.p1_cursor
                self.turn = 2
                self.p2_cursor = 5
                if not self.is_enabled(self.p2_cursor):
                    self.p2_cursor = self.move_cursor(self.p2_cursor, "down")

        elif self.turn == 2:
            if event.key == pygame.K_UP:
                self.p2_cursor = self.move_cursor(self.p2_cursor, "up")
            elif event.key == pygame.K_DOWN:
                self.p2_cursor = self.move_cursor(self.p2_cursor, "down")
            elif event.key == pygame.K_LEFT:
                self.p2_cursor = self.move_cursor(self.p2_cursor, "left")
            elif event.key == pygame.K_RIGHT:
                self.p2_cursor = self.move_cursor(self.p2_cursor, "right")
            elif event.key == pygame.K_RETURN:
                if not self.is_enabled(self.p2_cursor):
                    return

                self.p2_index = self.p2_cursor

                name_to_class = {
                    "佩恩头像.jpg": PlayerPain,
                    "鸣人头像.jpg": PlayerNaruto,
                    "千手柱间头像.jpg": PlayerHashirama,
                }

                p1_name = self.names[self.p1_index]
                p2_name = self.names[self.p2_index]

                self.game.change_scene(
                    SceneLoadingFight(
                        self.game,
                        name_to_class[p1_name],
                        name_to_class[p2_name],
                        p1_name,
                        p2_name
                    )
                )

    def update(self):
        if self.enter_lock_frames > 0:
            self.enter_lock_frames -= 1

        self.timer += 1
        if self.timer >= self.speed:
            self.timer = 0
            self.frame_index += 1
            if self.frame_index >= self.frame_count:
                self.frame_index = 0

    def draw(self, screen):
        x = self.frame_index * self.frame_w
        rect = pygame.Rect(x, 0, self.frame_w, self.frame_h)
        screen.blit(self.img, (0, 0), rect)

        for i, (hx, hy) in enumerate(self.positions):
            if self.is_enabled(i):
                screen.blit(self.heads[i], (hx, hy))
            else:
                screen.blit(self.gray[i], (hx, hy))

        if self.p1_index is not None:
            x, y = self.positions[self.p1_index]
            screen.blit(self.p1_box, (x - 5, y - 5))

        if self.p2_index is not None:
            x, y = self.positions[self.p2_index]
            screen.blit(self.p2_box, (x - 5, y - 5))

        if self.turn == 1:
            x, y = self.positions[self.p1_cursor]
            pygame.draw.rect(screen, (255, 0, 0), (x - 5, y - 5, 90, 90), 3)
        elif self.turn == 2:
            x, y = self.positions[self.p2_cursor]
            pygame.draw.rect(screen, (0, 255, 255), (x - 5, y - 5, 90, 90), 3)