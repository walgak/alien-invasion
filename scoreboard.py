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

    def prep_score(self):
        """Render the score image"""
        score_str = str(self.stats.score)
        self.score_image = self.font.render(score_str, True, self.text_color, self.settings.bg_color)

        #Display the score at the top right.
        self.screen_rect = self.score_image.get_rect()
        self.screen_rect.right = self.settings.screen_width -20
        self.screen_rect.top = 20

    def show_score(self):
        """Show the scoreboard"""
        self.screen.blit(self.score_image, self.screen_rect)