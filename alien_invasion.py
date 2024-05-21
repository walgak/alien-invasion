import sys
from time import sleep

import pygame

from settings import Settings
from ship import Ship
from bullet import Bullet
from alien import Alien
from game_stats import GameStats
from button import Button

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

        #Create an instance to store game stats
        self.stats = GameStats(self)

        self.ship = Ship(self)
        self.bullets = pygame.sprite.Group()
        self.aliens = pygame.sprite.Group()

        self._create_fleet()

        #Start the gave in an active state
        self.game_active = False

        #Make a play button
        self.play_button = Button(self, "Play")

    def run_game(self):
        """Starts the main loop for the game"""
        while True:
            self._check_events()

            if self.game_active:
                self.ship.update()
                self._update_bullets()
                self._update_aliens()

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
            elif event.type == pygame.MOUSEBUTTONDOWN:
                mouse_pos = pygame.mouse.get_pos()
                self._check_play_button(mouse_pos)
    
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
    
    def _check_play_button(self, mouse_pos):
        """Start game when the pllayer click's play"""
        button_clicked = self.play_button.rect.collidepoint(mouse_pos)
        if button_clicked and not self.game_active:
            #Reset game statistics
            self.settings.initialize_dynamic_settings()
            self.stats.reset_stats()
            self.game_active = True

            #Get rid of any remaining aliens and bullets
            self.bullets.empty()
            self.aliens.empty()

            #Create a new fleet and center the ship
            self._create_fleet()
            self.ship.center_ship()

            #Hide mouse cursor.
            pygame.mouse.set_visible(False)

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

        self._Check_bullet_alien_collision()
        
    def _Check_bullet_alien_collision(self):
        """Check if a bullet has hit an alien ship and get rid of the bullet and ship if so"""
        collisions = pygame.sprite.groupcollide(self.bullets,self.aliens, True, True)

        if not self.aliens:
            #Destroy existing bullets and create new fleet.
            self.bullets.empty()
            self._create_fleet()
            self.settings.increase_speed()
            
    def _update_screen(self):
            """Updates the images on the screen, and flip to the new screen"""

            self.screen.fill(self.settings.bg_color)

            for bullet in self.bullets.sprites():
                bullet.draw_bullet()

            self.ship.blitme()
            self.aliens.draw(self.screen)

            #Draw the play button if the game is inactive
            if not self.game_active:
                self.play_button.draw_button()

            #Make the most recent drawn screen visible
            pygame.display.flip()

    def _update_aliens(self):
        """Update the positions of all alien ships"""
        self._check_fleet_edges()
        self.aliens.update()

        #look for alien-ship collisions
        if pygame.sprite.spritecollideany(self.ship,self.aliens):
            self._ship_hit()
        
        #Check for aliens that reach the bottom
        self._check_aliens_bottom()
    
    def _create_fleet(self):
        """Creates a fleet of Alien ships"""
        #Make an alien ship and add it to the fleet
        alien = Alien(self)
        alien_width, alien_height = alien.rect.size

        current_x, current_y = alien_width, -alien_height * 2
        while current_y < (self.settings.screen_height - 10 * alien_height):
            while current_x < (self.settings.screen_width - 2 * alien_width):
                self._create_alien(current_x, current_y)
                current_x += 2 * alien_width
            current_x = alien_width
            current_y += 2 * alien_height

    def _create_alien(self, x_position, y_position):
            """Create a new alien"""
            new_alien = Alien(self)
            new_alien.x = x_position
            new_alien.rect.x = x_position
            new_alien.rect.y = y_position
            self.aliens.add(new_alien)
    
    def _check_fleet_edges(self):
        """Responds appropriately if an alien ship has reach either end"""
        for alien in self.aliens.sprites():
            if alien.check_edges():
                self._change_fleet_direction()
                break
    
    def _change_fleet_direction(self):
        """Lower the fleet and change its direction"""
        for alien in self.aliens.sprites():
            alien.rect.y += self.settings.fleet_drop_speed
        self.settings.fleet_direction *= -1

    def _ship_hit(self):
        """Respond to a ship being hit by an alien ship"""
        #Decrement ships(Lives) left
        if self.stats.ships_left > 0:
            self.stats.ships_left -= 1

            #Clear screen for aliens and bullets
            self.bullets.empty()
            self.aliens.empty()

            #Create a new alien fleet and center the ship
            self._create_fleet()
            self.ship.center_ship()

            #Pause game.
            sleep(0.5)
        else:
            self.game_active = False
            pygame.mouse.set_visible(True)

    def _check_aliens_bottom(self):
        """Check if any alien ship has reached the bottom"""
        for alien in self.aliens.sprites():
            if alien.rect.bottom >= self.settings.screen_height:
                #Same outcome as if the ship gets hit by an alien
                self._ship_hit()
                break

if __name__ == '__main__':
    #Make a game instance, and run the game.
    ai = AlienInvasion()
    ai.run_game()
                    