module GamesHelper
  def num_players
    @num_players ||= @game.config[:players].compact.size
  end

  def board_layout
    @board_layout ||= begin
                        layout = YAML.load_file("config/board-layout.yml")
                        num_players = @game.config[:players].compact.size
                        layout[num_players]
                      end
  end
end
