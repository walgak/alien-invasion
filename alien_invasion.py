import sys

import pygame

class AlienInvasion:
    """This is the master class that will manage all game assets and behavior."""

    def __init__(self):
        """Initializes the game and creates game resources."""
        pygame.init()

        self.screen = pygame.display.set_mode((1200, 800))
        pygame.display.set_caption("ALien Invasion")

    def run_game(self):
        """Starts the main loop for the game"""
        while True:
            #Listing to keyboard and mouse events
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    sys.exit()

            #Make the most recent drawn screen visible
            pygame.display.flip()
    
if __name__ == '__main__':
    #Make a game instance, and run the game.
    ai = AlienInvasion()
    ai.run_game()
                    