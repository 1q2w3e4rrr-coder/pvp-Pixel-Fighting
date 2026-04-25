class Animation:

    def __init__(self, frames, speed=5, loop=True):

        self.frames = frames

        self.speed = speed

        self.loop = loop

        self.index = 0

        self.timer = 0

        self.finished = False


    def reset(self):

        self.index = 0
        self.timer = 0
        self.finished = False


    def update(self):

        if self.finished:
            return

        self.timer += 1

        if self.timer >= self.speed:

            self.timer = 0

            self.index += 1

            if self.index >= len(self.frames):

                if self.loop:

                    self.index = 0

                else:

                    self.index = len(self.frames) - 1
                    self.finished = True


    def get(self):

        return self.frames[self.index]