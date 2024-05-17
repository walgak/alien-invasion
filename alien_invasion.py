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
            self._check_events()
            self.ship.update()
            #Redraw the screen during each pass through the loop
            self._update_screen()
            self.clock.tick(60)
    
    def _check_events(self):
        """Respond to keypresses and mouse events."""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_RIGHT:
                    #Move the ship to the right.
                    self.ship.moving_right = True
                elif event.key == pygame.K_LEFT:
                    #Move to the left.
                    self.ship.moving_left = True
            elif event.type == pygame.KEYUP:
                if event.key == pygame.K_RIGHT:
                    self.ship.moving_right = False
                elif event.key == pygame.K_LEFT:
                    self.ship.moving_left = False
            
    def _update_screen(self):
            """Updates the images on the screen, and flip to the new screen"""

            self.screen.fill(self.settings.bg_color)
            self.ship.blitme()

            #Make the most recent drawn screen visible
            pygame.display.flip()

if __name__ == '__main__':
    #Make a game instance, and run the game.
    ai = AlienInvasion()
    ai.run_game()
                    