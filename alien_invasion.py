import sys

import pygame

from settings import Settings
from ship import Ship
from bullet import Bullet

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
        self.bullets = pygame.sprite.Group()

    def run_game(self):
        """Starts the main loop for the game"""
        while True:
            self._check_events()
            self.ship.update()
            self._update_bullets()
            self._update_screen()
            self.clock.tick(60)
    
    def _check_events(self):
        """Respond to keypresses and mouse events."""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                self._check_keydowns(event)
            elif event.type == pygame.KEYUP:
                self._check_keyups(event)
    
    def _check_keydowns(self, event):
        if event.key == pygame.K_RIGHT:
            #Move the ship to the right.
            self.ship.moving_right = True
        elif event.key == pygame.K_LEFT:
            #Move to the left.
            self.ship.moving_left = True
        elif event.key == pygame.K_q:
            sys.exit()
        elif event.key == pygame.K_SPACE:
            self._fire_bullet()

    
    def _check_keyups(self, event):
        if event.key == pygame.K_RIGHT:
            self.ship.moving_right = False
        elif event.key == pygame.K_LEFT:
            self.ship.moving_left = False
    
    def _fire_bullet(self):
        """Create anew bullet and add it to the bullets group"""
        if len(self.bullets) < self.settings.bullets_allowed:
            new_bullet = Bullet(self)
            self.bullets.add(new_bullet)
        
    def _update_bullets(self):
        """Updates position of bullets and gets rid of bullet's already out of screen"""
        #update bullet positions
        self.bullets.update()
            #Getting rid of bullets that left the screen
        for bullet in self.bullets.copy():
            if bullet.rect.bottom <= 0:
                self.bullets.remove(bullet)
            
    def _update_screen(self):
            """Updates the images on the screen, and flip to the new screen"""

            self.screen.fill(self.settings.bg_color)

            for bullet in self.bullets.sprites():
                bullet.draw_bullet()

            self.ship.blitme()

            #Make the most recent drawn screen visible
            pygame.display.flip()

if __name__ == '__main__':
    #Make a game instance, and run the game.
    ai = AlienInvasion()
    ai.run_game()
                    