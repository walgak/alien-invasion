import pygame

class Ship:
    """A class to manage the ship"""
    #Attribute 'game' is of type AlienInvation from alien_invation.py

    def __init__(self, game):
        """Initialize the ship and set it's starting postion"""
        self.screen = game.screen
        self.screen_rect = game.screen.get_rect()

        #Load ship image and get its rect
        self.image = pygame.image.load('images/ship.bmp')
        self.rect = self.image.get_rect()

        #Set ship position to the bottom of the sreen
        self.rect.midbottom = self.screen_rect.midbottom

    def blitme(self):
        """Draw the ship at it's current location"""
        self.screen.blit(self.image, self.rect)