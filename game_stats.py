"""Legacy Pygame run statistics. reset_stats() resets lives, score and level but intentionally preserves the in-memory high score; this original version does not save it to disk."""

class GameStats:
    """Tracks all game statistics"""

    def __init__(self,game):
        """Initialize statistics"""
        self.settings = game.settings
        #High score should never be reset
        self.high_score = 0

        self.reset_stats()

    def reset_stats(self):
        """Initialize stats that can change during gameplay"""
        self.ships_left = self.settings.ships_left
        self.score = 0
        self.level = 1
