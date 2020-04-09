module GamesHelper

  def cards_shown_on_table
    cards = []
    cards << [ "#{@trump.suit}", "#{@trump.abbreviated_name}", "trump" ]
    if @played_cards && !@played_cards.empty?
      # TODO: loop for X players
      {
        0 => :bottom,
        1 => :left,
        2 => :top,
        3 => :right
      }.each do |i, side|
        next unless @played_cards[i].present?
        cards << [@played_cards[i].suit, @played_cards[i].abbreviated_name, side] 
      end
    end
    cards
  end
end
