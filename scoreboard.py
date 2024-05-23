import pygame.font

class Scoreboard:
    """Class for displaying a scoreboard"""

    def __init__(self, game):
        """Initialize scorekeeping attributes."""
        self.screen = game.screen
        self.screen_rect = self.screen.get_rect()
        self.settings = game.settings
        self.stats = game.stats

        #Font settings for scoring information
        self.text_color = (30,30,30)
        self.font = pygame.font.SysFont(None, 48)

        #Prepare the initial score image.
        self.prep_score()
        self.prep_high_score()

    def prep_score(self):
        """Render the score image"""
        rounded_score = round(self.stats.score, -1)
        score_str = f"{rounded_score:,}"
        self.score_image = self.font.render(score_str, True, self.text_color, self.settings.bg_color)

        #Display the score at the top right.
        self.screen_rect = self.score_image.get_rect()
        self.screen_rect.right = self.settings.screen_width -20
        self.screen_rect.top = 20

    def show_score(self):
        """Show the scoreboard"""
        self.screen.blit(self.score_image, self.screen_rect)
        self.screen.blit(self.high_score_image, self.high_score_rect)

    def prep_high_score(self):
        """Turn the high score into a rendered image."""
        high_score = round(self.stats.high_score, -1)
        high_score_str = f"{high_score:,}"
        self.high_score_image = self.font.render(high_score_str, True, self.text_color, self.settings.bg_color)

        #Center the high score image on top of the screen.
        self.high_score_rect = self.high_score_image.get_rect()
        self.high_score_rect.centerx = self.settings.screen_width/2
        self.high_score_rect.top = self.screen_rect.top

    def check_high_score(self):
        """Check if ther's a new high score"""
        if self.stats.score > self.stats.high_score:
            self.stats.high_score = self.stats.score
            self.prep_high_score()