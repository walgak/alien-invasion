import sys

import pygame

from settings import Settings
from ship import Ship

class AlienInvasion:
    """This is the master class that will manage all game assets and behavior."""

    def __init__(self):
        """Initializes the game and creates game resources."""
        pygame.init()
        self.clock = pygame.time.Clock()
        self.settings = Settings()

        #Create a display window
        self.screen = pygame.display.set_mode((self.settings.screen_width,self.settings.screen_height))
        pygame.display.set_caption("ALien Invasion")
        self.ship = Ship(self)

    def run_game(self):
        """Starts the main loop for the game"""
        while True:
            #Listing to keyboard and mouse events
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    sys.exit()
            
            #Redraw the screen during each pass through the loop
            self.screen.fill(self.settings.bg_color)
            self.ship.blitme()

            #Make the most recent drawn screen visible
            pygame.display.flip()
            self.clock.tick(60)
    
if __name__ == '__main__':
    #Make a game instance, and run the game.
    ai = AlienInvasion()
    ai.run_game()
                    