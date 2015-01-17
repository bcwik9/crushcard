class Game < ActiveRecord::Base
  attr_accessor :players
  
  def play
    raise 'Invalid number of players' if players.size < 3 or players.size > 5
    # set up game
    total_rounds = 10 # typical game of crush is comprised of 10 rounds
    rounds_played = 0
    deck = Card.get_deck
    @players.shuffle!

    while rounds_played < total_rounds
      # shuffle deck/players
      deck.shuffle!
      
      # deal out number of cards equal to whatever round we are on
      num_cards_per_player = total_rounds - rounds_played
      @players.each do |player|
        player.inventory = deck.slice!(0..(num_cards_per_player-1))
      end

      # the next card in the deck is trump
      # whatever suit is trump is valued higher than non-trump suits
      # an Ace as trump means there is "no trump"
      trump = deck.slice! 0

      # players each take turns making bids
      # dealer bids last
      dealer = @players[rounds_played % @players.size]
      bids = {}
      total_bids = 0
      highest_bid = -1
      highest_bidder = nil
      iterate_through_list_with_start_index(@players.find_index(dealer)+1, @players) { |current_bidder|
        bid = current_bidder.place_bid
        # dealer cannot bid the same amount as the number of cards dealt
        while dealer == current_bidder and total_bids + bid == num_cards_per_player
          bid = current_bidder.place_bid
        end
        
        if bid > highest_bid
          highest_bid = bid 
          highest_bidder = current_bidder
        end
        bids[player] = bid
        total_bids += bid
      }
      
      # once all bids are recorded, play starts
      # the player who bid the highest first is who starts
      player_who_took_last_trick = highest_bidder
      tricks_taken = {}
      @players.each do |p| tricks_taken[p] = 0 end
      num_cards_per_player.times do |i|
        cards_played = []
        iterate_through_list_with_start_index(@players.find_index(player_who_took_last_trick), @players) { |player|
          # keep asking for a card until the player gives a valid card
          first_suit_played = cards_played.empty? ? nil : cards_played.first.suit
          playable_cards = get_playable_cards first_suit_played, player
          while(not playable_cards.include?(player_card = player.play_card)) end
          # put the card in play
          cards_played.push player_card
        }

        # after everyone has played a card, we need to determine who won the trick
        winning_player = get_highest_card(cards_played) # fix this
        
      end
      
      # done with the round
      rounds_played += 1
    end
  end

  def get_highest_card cards, trump
    # implement this
  end
  
  def get_playable_cards first_suit_played, player
    # player can play any card if they are the first to play a card
    # or if they only have a single card left
    return player.inventory if first_suit_played.nil? or player.inventory.size == 1
    # player must play the same suit as the first card played
    playable_cards = player.inventory.select { |card| card.suit == first_suit_played }
    # if player doesn't have any of the same suit as the first card played
    # they can play any card
    playable_cards = player.inventory if playable_cards.empty?
    end
  end

  def iterate_through_list_with_start_index start_index, list
    players.size.times do |offset|
      index = (start_index + offset) % list.size
      yield list[index]
    end
  end
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
  
  def <=> other
    @value <=> other.value
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
    @inventory = []
  end

  def place_bid
    raise 'TODO: implement me!' # TODO: implement this
    return 0
  end

  # play a card from the inventory
  def play_card
    raise 'TODO: implement me!' # TODO: implement this
  end
end
