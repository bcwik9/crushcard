module GamesHelper

  def cards_shown_on_table
    cards = @played_cards || []
    (0..3).each do |i|
      cards[i] = @played_cards[i] 
    end
    cards
  end

end
