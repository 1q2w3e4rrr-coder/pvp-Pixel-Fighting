import pygame

from ui.select import SceneSelect


class SceneMenu:

    def __init__(self, game):

        self.game = game

        self.bg = pygame.image.load(
            "assets/游戏界面/死神vs火影封面.jpg"
        ).convert()

        self.bg = pygame.transform.scale(
            self.bg,
            (1500, 800)
        )


    def handle_event(self, event):

        if event.type == pygame.KEYDOWN:

            if event.key == pygame.K_RETURN:

                self.game.change_scene(
                    SceneSelect(self.game)
                )


    def update(self):
        pass


    def draw(self, screen):

        screen.blit(self.bg, (0, 0))