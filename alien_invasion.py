import sys

import pygame

class AlienInvasion:
    """This is the master class that will manage all game assets and behavior."""

    def __init__(self):
        """Initializes the game and creates game resources."""
        pygame.init()
        self.clock = pygame.time.Clock()

        #Create a display window
        self.screen = pygame.display.set_mode((1000, 700))
        pygame.display.set_caption("ALien Invasion")

        #Set background color
        self.bg_color = (230,230,230)

    def run_game(self):
        """Starts the main loop for the game"""
        while True:
            #Listing to keyboard and mouse events
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    sys.exit()
            
            #Redraw the screen during each pass through the loop
            self.screen.fill(self.bg_color)

            #Make the most recent drawn screen visible
            pygame.display.flip()
            self.clock.tick(60)
    
if __name__ == '__main__':
    #Make a game instance, and run the game.
    ai = AlienInvasion()
    ai.run_game()
                    