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

        #Motion flag; start with a ship that's not moving.
        self.moving_right = False
        self.moving_left = False


    def update(self):
        """Update the ship's movement based on the movement flag"""
        if self.moving_right:
            self.rect.x += 3
        if self.moving_left:
            self.rect.x -= 3

    def blitme(self):
        """Draw the ship at it's current location"""
        self.screen.blit(self.image, self.rect)