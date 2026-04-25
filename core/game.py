import pygame

from ui.menu import SceneMenu


class Game:

    def __init__(self):

        pygame.init()

        self.screen = pygame.display.set_mode((1500, 800))

        pygame.display.set_caption("BVN Python")

        self.clock = pygame.time.Clock()

        self.scene = SceneMenu(self)


    def change_scene(self, scene):

        self.scene = scene


    def run(self):

        while True:

            for event in pygame.event.get():

                if event.type == pygame.QUIT:

                    pygame.quit()
                    exit()

                self.scene.handle_event(event)

            self.scene.update()

            self.scene.draw(self.screen)

            pygame.display.update()

            self.clock.tick(60)