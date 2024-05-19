class GameStats:
    """Tracks all game statistics"""

    def __init__(self,game):
        """Initialize statistics"""
        self.settings = game.settings
        self.reset_stats()

    def reset_stats(self):
        """Initialize stats that can change during gameplay"""
        self.ships_left = self.settings.ships_left