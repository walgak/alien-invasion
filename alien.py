import pygame
from pygame.sprite import Sprite

class Alien(Sprite):
    """A class for a single Alien ship"""

    def __init__(self, game):
        """Initialize Alien ship and set it's position"""
        super().__init__()
        self.screen = game.screen
        self.settings = game.settings

        #Load the Alien image and set its rect attributes
        self.image = pygame.image.load('images/alien.bmp')
        self.rect = self.image.get_rect()

        #Start each new Alien near the top left of the screen
        self.rect.x = self.rect.width
        self.rect.y = self.rect.width

        #Store the Alien's exact horizontal position
        self.x = float(self.rect.x)

    def check_edges(self):
        """Return true if an alien ship has reached the end of the screen"""
        screen_rect = self.screen.get_rect()
        return (self.rect.right >= screen_rect.right) or (self.rect.left <= 0)

    def update(self):
        """Move the Alien"""
        self.x += self.settings.alien_speed * self.settings.fleet_direction
        self.rect.x = self.x