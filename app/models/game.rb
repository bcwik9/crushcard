class Game < ActiveRecord::Base
  require 'yaml'

  def set_up
    state = {}

    state[:total_rounds] = 10
    state[:rounds_played] = 0
    state[:players] = []
    state[:player_hands] = []
    state[:score] = []
    state[:deck] = []

    state[:players].shuffle!

    save_state state
  end
  
  def deal_cards state
    # shuffle deck
    state[:deck] = Card.get_deck
    state[:deck].shuffle!

    # determine who the dealer is
    state[:dealer] = state[:players][state[:rounds_played] % state[:players].size]

    # reset bids hash and determine who bids first
    # person to the 'right' of the dealer bids first
    state[:bids] = []
    state[:waiting_on] = state[:players][state[:players].find_index(state[:dealer]) + 1]
    
    # deal out number of cards equal to whatever round we are on
    # to each player
    # deal cards first to player on 'right' of dealer
    num_cards_per_player = state[:total_rounds] - state[:rounds_played]
    iterate_through_list_with_start_index(state[:players].find_index(state[:waiting_on]), state[:players]) { |player, i|
      state[:player_hands][i] = state[:deck].slice!(0..(num_cards_per_player-1))
    }
    
    # the next card in the deck is trump
    # whatever suit is trump is valued higher than non-trump suits
    # an Ace as trump means there is "no trump"
    state[:trump_card] = deck.slice! 0
    trump = (state[:trump_card].value_name =~ /ace/i) ? nil : state[:trump_card].suit

    # set a few default values
    state[:cards_in_play] = []
    state[:first_suit_played] = nil
    state[:tricks_taken] = []
  end

  # player either bids or plays a card if it's their turn
  def player_action
    state = load_state
    
    # return false if it's not the players turn
    return false if session[:id] != state[:waiting_on]

    current_player_index = state[:players].find_index session[:id]
    
    # check if we are in bidding or playing a card
    if state[:bids].include?(nil)
      # player is making a bid
      bid = INPUT # TODO: replace this with form value
      
      # dealer cannot bid the same amount as the number of cards dealt
      total_bids = state[:bids].inject(:+)
      num_cards_per_player = state[:total_rounds] - state[:rounds_played]
      if state[:dealer] == session[:id] and total_bids + bid == num_cards_per_player
        return false
      end
      
      # record the bid
      state[:bids][current_player_index] = bid

      if state[:dealer] == session[:id]
        # dealer is last to bid
        # so now determine who bid the highest, since they are the
        # first to play a card
        # bidding is done at this point
        iterate_through_list_with_start_index(current_player_index+1, state[:bids]) do |bid,i|
          if state[:bids].max == bid
            state[:waiting_on] = state[:players][i]
            break
          end
        end
      else
        # set next player to bid
        state[:waiting_on] = get_next_player state[:waiting_on], state[:players]
      end

    elsif not state[:player_hands][current_player_index].empty?
      # player is playing a card
      card = INPUT
      
      # ensure that the card is in their inventory
      return false unless state[:player_hands][current_player_index].include? card

      # ensure that the card is actually playable
      state[:first_suit_played] ||= card.suit
      playable_cards = get_playable_cards state[:first_suit_played], state[:player_hands][current_player_index]
      return false unless state[:player_hands][current_player_index].include? card
      
      # actually play the card
      state[:cards_in_play][current_player_index] = state[:player_hands][current_player_index].delete(card)

      # check to see if all players have played a card
      if not state[:cards_in_play].include?(nil)
        # determine who won the trick
        highest_card = get_highest_card(state[:cards_in_play], state[:trump_card].suit, current_player_index+1)
        winner_index = state[:cards_in_play].find_index(highest_card)
        state[:tricks_taken][winner_index] ||= []
        state[:tricks_taken][winner_index].push state[:cards_in_play]

        # reset variables
        state[:cards_in_play] = []
        state[:first_suit_played] = nil
        

        # check to see if we're done with this round
        if state[:player_hands].first.empty?
          # increment rounds played
          state[:rounds_played] += 1

          # determine scores
          state[:tricks_taken].each_with_index do |tricks, i|
            if tricks.size < state[:bids][i]
              player_score = tricks.size - state[:bids][i]
            elsif tricks.size > state[:bids][i]
              player_score = tricks.size
            else
              player_score = tricks.size + 10
            end
            state[:score].push player_score
          end
        
          # check to see if that was the last round (game over)
          if state[:rounds_played] == state[:total_rounds]
            # game is over, determine who won
            state[:winners] = []
            highest_score = nil
            state[:score].each_with_index do |score, i|
              player_score = score.inject :+ # add up score from each round
              if highest_score.nil? or player_score >= highest_score
                highest_score = player_score
                state[:winners].clear if player_score > highest_score
                state[:winners].push state[:players][i]
              end
            end
            # TODO: implement something to notify game has ended and who won
          else
            # deal cards for the next round
            deal_cards state
          end
        else
          # winner is the first to play a card next
          state[:waiting_on] = state[:players][winner_index]
        end
      else
        # set next player to play a card
        state[:waiting_on] = get_next_player state[:waiting_on], state[:players]   
      end
    end
    
    save_state state
    return true
  end

  def load_state
    return self.state.to_yaml
  end
  
  def save_state state
    self.state = state.to_yaml
  end

  def get_highest_card cards, trump, start_index
    return cards.first if cards.size <= 1

    trump_cards = cards.select { |c| c.suit == trump }
    card_set = trump_cards.empty? ? cards : trump_cards
    highest_value = card_set.max
    iterate_through_list_with_start_index(start_index, card_set) do |card|
      return card if card.value == highest_value
    end
  end
  
  def get_playable_cards first_suit_played, cards
    # player can play any card if they are the first to play a card
    # or if they only have a single card left
    return cards if first_suit_played.nil? or cards.size == 1
    # player must play the same suit as the first card played
    playable_cards = cards.select { |card| card.suit == first_suit_played }
    # if player doesn't have any of the same suit as the first card played
    # they can play any card
    playable_cards = cards if playable_cards.empty?
    return playable_cards
  end

  def iterate_through_list_with_start_index start_index, list
    list.size.times do |offset|
      index = (start_index + offset) % list.size
      yield list[index], index
    end
  end

  def get_next_player current_player, players
    return (players.find_index(current_player) + 1) % players.size
  end
end

class Card
  include Comparable
  
  SUITS = %w{Spades Hearts Diamonds Clubs}
  attr_accessor :suit, :value

  # create a single card
  def initialize suit, value
    raise 'Invalid card suit' unless SUITS.include? suit
    raise 'Invalid card value' unless value >= 0 and value < 13
    @suit = suit
    @value = value
  end

  def value_name
    card_names = %w[Two Three Four Five Six Seven Eight Nine Ten Jack Queen King Ace]
    return card_names[value]
  end
  
  def <=> other
    @value <=> other.value
  end

  def == other
    return (@value == other.value and @suit == other.suit)
  end

  # creates a standard deck of 52 cards, Ace high
  # the '0' represents 2, and '12' is Ace
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
