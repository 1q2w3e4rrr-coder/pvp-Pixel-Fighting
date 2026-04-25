from core.animation import Animation


class Animator:

    def __init__(self):

        self.animations = {}

        self.current = None


    def add(self, name, anim):

        self.animations[name] = anim


    def play(self, name):

        if self.current != name:

            self.current = name

            self.animations[name].reset()


    def update(self):

        if self.current:

            self.animations[self.current].update()


    def get(self):

        if self.current:

            return self.animations[self.current].get()

        return None