class StateMachine:

    def __init__(self):

        self.state = "idle"

        self.timer = 0


    def set(self, name):

        if self.state != name:

            self.state = name
            self.timer = 0


    def update(self):

        self.timer += 1


    def is_state(self, name):

        return self.state == name