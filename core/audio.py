import os
import pygame


class AudioManager:
    def __init__(self):
        self.current = None
        self.enabled = True

        self.beginning_path = os.path.join("assets", "音频", "beginning.mp3")
        self.fight_path = os.path.join("assets", "音频", "bleach.mp3")
        self.click_path = os.path.join("assets", "音频", "clicksound.mp3")

        self.click_sound = None

        try:
            if pygame.mixer.get_init() is None:
                pygame.mixer.init()

            if os.path.exists(self.click_path):
                self.click_sound = pygame.mixer.Sound(self.click_path)
                self.click_sound.set_volume(0.8)
            else:
                print("找不到点击音效:", self.click_path)

        except pygame.error as e:
            print("音频初始化失败:", e)
            self.enabled = False

    def _play_music(self, path, name, volume=0.6):
        if not self.enabled:
            return

        if self.current == name:
            return

        if not os.path.exists(path):
            print("找不到音频文件:", path)
            return

        try:
            pygame.mixer.music.stop()
            pygame.mixer.music.load(path)
            pygame.mixer.music.set_volume(volume)
            pygame.mixer.music.play(-1)
            self.current = name
        except pygame.error as e:
            print("播放音频失败:", path, e)

    def play_beginning(self):
        self._play_music(self.beginning_path, "beginning", volume=0.6)

    def play_fight(self):
        self._play_music(self.fight_path, "fight", volume=0.6)

    def play_click(self):
        if not self.enabled:
            return

        if self.click_sound is not None:
            self.click_sound.play()

    def stop(self):
        if self.enabled:
            pygame.mixer.music.stop()
        self.current = None