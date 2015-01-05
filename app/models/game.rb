class Game < ActiveRecord::Base
  attr_accessor :players
  

end


class Card
  SUITS = %w{Spades Hearts Diamonds Clubs}
  attr_accessor :suit, :value

  # create a single card
  def initialize suit, value
    raise 'Invalid card suit' unless SUITS.include? suit
    raise 'Invalid card value' unless value >= 0 and value < 13
    @suit = suit
    @value = value
  end

  # creates a standard deck of 52 cards
  def self.get_deck
    cards = []
    SUITS.each do |suit|
      1..13.times do |i|
        cards.push Card.new(suit, i)
      end
    end
    return cards
  end
end

class Player
  attr_accessor :name, :inventory

  def initialize name
    raise 'Invalid player name' if name.nil? or name.empty?
    @name = name
  end
end
