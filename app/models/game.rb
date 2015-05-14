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
    state[:names] = []

    state[:players].shuffle!

    save_state state
  end
  
  def deal_cards state
    # need to have at least 3 players to start the game
    raise 'Must have between 3 and 5 players to start' if state[:players].size < 3 or state[:players].size > 5

    # shuffle deck
    state[:deck] = Card.get_deck
    state[:deck].shuffle!

    # determine who the dealer is
    state[:dealer] = state[:players][state[:rounds_played] % state[:players].size]

    # reset bids hash and determine who bids first
    # person to the 'left' of the dealer bids first
    state[:bids] = []
    state[:waiting_on] = get_next_player state[:dealer], state[:players]
    
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
    state[:trump_card] = state[:deck].slice! 0

    # Continuously get cpu players' bids until we get to a human player
    while is_cpu_player? state[:waiting_on] and not done_bidding? state
      bid = get_possible_bids( 
                              num_cards_per_player,
                              state[:bids],
                              state[:waiting_on] == state[:dealer]
                              ).sample
      state[:bids][state[:players].find_index state[:waiting_on]] = bid
      state[:waiting_on] = get_next_player state[:waiting_on], state[:players]
    end

    # set a few default values
    state[:cards_in_play] = []
    state[:first_suit_played] = nil
    state[:tricks_taken] = []

    return state
  end

  # player either bids or plays a card if it's their turn
  def player_action user_id, user_input=nil
    state = load_state
    
    # return false if it's not the players turn
    return false if user_id != state[:waiting_on]

    current_player_index = state[:players].find_index user_id
    
    # check if we are in bidding or playing a card
    if !done_bidding? state
      # player is making a bid
      bid = user_input.to_i
      
      num_cards_per_player = state[:total_rounds] - state[:rounds_played]
      
      # make sure bid is valid
      return false if not get_possible_bids(
                                            num_cards_per_player,
                                            state[:bids],
                                            state[:dealer] == user_id
                                            ).include? bid
      
      # record the bid
      state[:bids][current_player_index] = bid

      # make bids for computers until we get to a human player
      # OR all players have made a bid
      while state[:dealer] != state[:waiting_on]
        # set next player to bid
        state[:waiting_on] = get_next_player state[:waiting_on], state[:players]
        current_player_index = state[:players].find_index state[:waiting_on]

        # if it's the computer's turn, let them bid
        if is_cpu_player? state[:waiting_on]
          bid = get_possible_bids( num_cards_per_player,
                                   state[:bids],
                                   state[:waiting_on] == state[:dealer] ).sample
          state[:bids][current_player_index] = bid
        else
          # we've encountered a human who has to bid
          # so save the state and let them input a bid
          save_state state
          return true
        end
      end

      # dealer is last to bid so now determine who bid the highest,
      # since they are the first to play a card.
      # bidding for the round is done at this point
      iterate_through_list_with_start_index(current_player_index+1, state[:bids]) do |bid,i|
        if state[:bids].max == bid
          state[:waiting_on] = state[:players][i]
          current_player_index = state[:players].find_index state[:waiting_on]
          break
        end
      end

      # if a human needs to play a card, return now so they can play
      # otherwise continue and play some cards for the CPU
      unless is_cpu_player? state[:waiting_on]
        save_state state
        return true
      end

    end
    
    # keep playing cards until we're waiting on a player
    while not all_players_played_a_card? state
      playable_cards = get_playable_cards(state[:first_suit_played], state[:player_hands][current_player_index])

      # check to see if computer needs to play a card
      if is_cpu_player? state[:waiting_on]
        card = playable_cards.sample
      else
        card = user_input
        # ensure that the card is actually playable
        return false unless playable_cards.include? card
      end

      # actually play the card
      state[:first_suit_played] ||= card.suit
      state[:cards_in_play][current_player_index] = state[:player_hands][current_player_index].delete(card)

      # set next player to play a card
      state[:waiting_on] = get_next_player state[:waiting_on], state[:players]
      current_player_index = state[:players].find_index state[:waiting_on]

      # stop playing cards for CPUs since a player needs to play
      break if not is_cpu_player? state[:waiting_on]
    end

    if all_players_played_a_card? state
      # make sure nobody can do anything
      state[:waiting_on] = "Table to clear"
      delay.clear_table(current_player_index, state)
    end
    
    save_state state
    return true
  end

  # clear the table of cards and calculate who won the trick/game
  def clear_table current_player_index, state
    # sleep a bit so the table isn't cleared immediately
    sleep 2

    # determine who won the trick
    highest_card = get_highest_card(state[:cards_in_play], state[:first_suit_played], state[:trump_card], current_player_index+1)
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
        num_tricks_taken = tricks.nil? ? 0 : tricks.size
        if num_tricks_taken < state[:bids][i]
          player_score = num_tricks_taken - state[:bids][i]
        elsif num_tricks_taken > state[:bids][i]
          player_score = num_tricks_taken
        else
          player_score = num_tricks_taken + 10
        end
        state[:score][i] ||= []
        state[:score][i].push player_score
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
            # clear winners list if there's a new high score
            # winners list is necessary since there can be ties
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
      current_player_index = state[:players].find_index state[:waiting_on]

      # if the winner was the CPU, keep playing cards until we
      # get to a human player
      while is_cpu_player? state[:waiting_on]
        playable_cards = get_playable_cards(state[:first_suit_played], state[:player_hands][current_player_index])
        card = playable_cards.sample

        # actually play the card
        state[:first_suit_played] ||= card.suit
        state[:cards_in_play][current_player_index] = state[:player_hands][current_player_index].delete(card)

        # set next player to play a card
        state[:waiting_on] = get_next_player state[:waiting_on], state[:players]
        current_player_index = state[:players].find_index state[:waiting_on]
      end
    end

    save_state state
    self.save!
  end

  def load_state
    return YAML.load(self.state)
  end
  
  def save_state state
    self.state = state.to_yaml
  end

  def get_highest_card cards, first_suit_played, trump, start_index
    return cards.first if cards.size <= 1

    # if trump was played, ignore other cards
    # an ace indicates no trump, so ignore it if that's the case
    trump_cards = (trump.suit =~ /ace/i) ? [] : cards.select { |c| c.suit == trump.suit }

    # if trump wasn't played or there is no trump (ace),
    # only cards that are the same suit as the first card played matter
    same_suit_cards = cards.select { |c| c.suit == first_suit_played }
    card_set = trump_cards.empty? ? same_suit_cards : trump_cards
    
    # now simply get the highest card left
    return card_set.max
    #iterate_through_list_with_start_index(start_index, card_set) do |card|
    #  return card if card.value == highest_value
    #end
  end

  def get_possible_bids total_cards, bids, is_dealer
    result = (0..total_cards).to_a
    if is_dealer
      # dealer cannot bid the same amount as the number of cards dealt
      total_bids = bids.select { |bid| !bid.nil? }.inject(:+)
      result.delete( total_cards - total_bids )
    end
    return result
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

  # for now, a player is a cpu player if their id resembles a uuid
  def is_cpu_player? id
    return /^\w{8}-(\w{4}-){3}\w{12}$/ =~ id.to_s
  end

  def iterate_through_list_with_start_index start_index, list
    list.size.times do |offset|
      index = (start_index + offset) % list.size
      yield list[index], index
    end
  end

  # returns the index of the next player
  def get_next_player current_player, players
    return players[(players.find_index(current_player) + 1) % players.size]
  end

  # returns true if the input array is the same size as the number of
  # players we have, and doesn't include nil
  def player_size_and_nil_check arr, state
    return (arr.size == state[:players].size and not arr.include?(nil))
  end

  # return true or false if we're done bidding
  # done bidding if there are the same number of valid bids
  # as there are players in the game
  def done_bidding? state
    return player_size_and_nil_check(state[:bids], state)
  end

  def all_players_played_a_card? state
    return player_size_and_nil_check(state[:cards_in_play], state)
  end
end

class Card
  include Comparable
  
  SUITS = %w{Spades Hearts Diamonds Clubs}
  attr_accessor :suit, :value, :playable

  # create a single card
  def initialize suit, value
    raise 'Invalid card suit' unless SUITS.include? suit
    raise 'Invalid card value' unless value.to_i >= 0 and value.to_i < 13
    @suit = suit
    @value = value
  end

  def value_name
    card_names = %w[Two Three Four Five Six Seven Eight Nine Ten Jack Queen King Ace]
    return card_names[@value]
  end

  def abbreviated_name
    %w[2 3 4 5 6 7 8 9 10 J Q K A][@value]
  end
  
  def <=> other
    return 1 if other.nil?
    return 0 if @value.nil? and other.value.nil?
    return 1 if other.value.nil?
    return -1 if @value.nil?
    @value.to_i <=> other.value.to_i
  end

  def == other
    return false if other.nil?
    return false if (@value.nil? or other.value.nil?) and @value != other.value
    return (@value.to_i == other.value.to_i and @suit == other.suit)
  end
  
  def suit_order other
    if @suit != other.suit
      SUITS.index( @suit ) <=> SUITS.index( other.suit )
    else
      @value <=> other.value
    end
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
