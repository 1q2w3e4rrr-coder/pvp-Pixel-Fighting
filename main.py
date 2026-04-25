import sys
import os

sys.path.append(os.path.dirname(__file__))

from core.game import Game

if __name__ == "__main__":

    game = Game()

    game.run()