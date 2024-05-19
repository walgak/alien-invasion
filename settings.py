class Settings:
    """A class that stores all game settings"""

    def __init__(self):
        """Initialize the game settings"""
        #Screen settings
        self.screen_width = 1000
        self.screen_height = 700
        self.bg_color = (230,230,230)

        #Ship's speed
        self.ship_speed = 1.5

        #Bullet settings
        self.bullet_speed = 4.0
        self.bullet_width = 3
        self.bullet_height = 15
        self.bullet_color = (60,60,60)
        self.bullets_allowed = 3

        #Alien settings
        self.alien_speed = 1.0
        self.fleet_drop_speed = 10
        #Fleet direction of 1 represents right; -1 represents left
        self.fleet_direction = 1
