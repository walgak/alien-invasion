class Settings:
    """A class that stores all game settings"""

    def __init__(self):
        """Initialize the game settings"""
        #Screen settings
        self.screen_width = 1000
        self.screen_height = 700
        self.bg_color = (230,230,230)

        #Ship's speed
        self.ships_left = 3

        #Bullet settings
        self.bullet_width = 3
        self.bullet_height = 15
        self.bullet_color = (60,60,60)
        self.bullets_allowed = 3

        #Alien settings
        self.fleet_drop_speed = 10


        #Game speed rate
        self.speedup_scale = 1.3

        #Alien value increment
        self.score_scale = 1.5

        self.initialize_dynamic_settings()

        #Score settings
        self.alien_points = 50
    
    def initialize_dynamic_settings(self):
        """Initialize settings that change throughout the game"""
        self.ship_speed = 1.5
        self.bullet_speed = 4.0
        self.alien_speed = 2.0

        #Fleet direction of 1 represents right; -1 represents left
        self.fleet_direction = 1

    def increase_speed(self):
        """Increase game speed and icrement hit value."""
        self.ship_speed *= self.speedup_scale
        self.bullet_speed *= self.speedup_scale
        self.alien_speed *= self.speedup_scale

        self.alien_points = int(self.alien_points * self.score_scale)
