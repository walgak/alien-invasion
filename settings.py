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
