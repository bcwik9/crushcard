class Game < ActiveRecord::Base
  require 'yaml'

  def set_up
    state = {
      total_rounds: 10,
      rounds_played: 0,
      dealer_index: 0,
      waiting_on: nil, # creator 
      waiting_on_index: 0,
      waiting_on_reason: "Game to start",
      players: [],
      names: [],
      score: [],
      deck: [],
      player_hands: [],
      winner_index: nil,
      winners: [],
    }

    save_state state
  end

  def add_waiting_info(index, reason)
    player = config[:players][index]
    config.merge!(
      waiting_on: player, 
      waiting_on_index: index,
      waiting_on_reason: reason 
    )
  end

  def set_new_dealer
    # Could use dealer_index + 1 % size
    config[:dealer_index] = config[:rounds_played] % config[:players].size
    config[:dealer] = config[:players][config[:dealer_index]] # deprecated - use index
  end
  
  def deal_cards
    # need to have at least 3 players to start the game
    raise 'Must have between 3 and 5 players to start' if config[:players].size < 3 || config[:players].size > 5

    # shuffle deck
    config[:deck] = Card.get_deck
    config[:deck].shuffle!

    # reset bids hash and determine who bids first
    # person to the 'left' of the dealer bids first
    config[:bids] = []

    # next player is always +1 on dealer (could use waiting_on_index)
    to_left = (config[:dealer_index] + 1) % config[:players].size
    add_waiting_info(to_left, "Bid")
    
    num_cards_per_player = config[:total_rounds] - config[:rounds_played]
    # deal out number of cards equal to whatever round we are on
    # to each player
    # deal cards first to player on 'right' of dealer
    #iterate_through_list_with_start_index(to_left, config[:players]) { |player, i|
    config[:player_hands] = [] # reset
    config[:players].each_with_index do |p, i|
      config[:player_hands][i] = config[:deck].slice!(0..(num_cards_per_player-1))
    end
    
    # the next card in the deck is trump
    # whatever suit is trump is valued higher than non-trump suits
    # an Ace as trump means there is "no trump"
    config[:trump_card] = config[:deck].slice! 0

    # set a few default values
    config[:cards_in_play] = []
    config[:first_suit_played] = nil
    config[:tricks_taken] = []

    save_state config
  end

  def player_index(player_id)
    config[:players].index(player_id)
  end

  def player_up?(current_user)
    current_user_index = player_index(current_user)

    waiting_user = config[:waiting_on] # deprecated
    waiting_user_index = config[:waiting_on_index]
    info = "##{current_user_index} vs ##{waiting_user_index} - #{current_user} vs #{waiting_user}"
    if current_user_index != waiting_user_index 
      false
    elsif current_user != waiting_user # deprecated
      #raise "SHOULD NOT GET HERE"
      #false
      true
    else
      true
    end
  end

  # player either bids or plays a card if it's their turn
  def player_action user_id, user_input=nil
    return false unless player_up?(user_id)
    current_player_index = player_index(user_id)
    
    # check if we are in bidding or playing a card
    if !done_bidding?
      # player is making a bid
      bid = user_input.to_i
      # dealer cannot bid the same amount as the number of cards dealt
      total_bids = config[:bids].compact.sum
      num_cards_per_player = config[:total_rounds] - config[:rounds_played]

      all_add_up = total_bids + bid == num_cards_per_player
      is_dealer = config[:dealer] == user_id
      if is_dealer && all_add_up
        return false
      end
      
      # record the bid
      config[:bids][current_player_index] = bid

      if config[:dealer] == user_id
        # dealer is last to bid, bidding is done
        # determine who bid highest (first if tie), they are first to play a card
        max_bid = config[:bids].max
        iterate_through_list_with_start_index(current_player_index+1, config[:bids]) do |bid,i|
          if max_bid == bid
            add_waiting_info(@player_index, "Play")
            break
          end
        end
      else
        to_left = next_player_index config[:waiting_on_index]
        add_waiting_info(to_left, "Bid")
      end

    elsif !config[:player_hands][current_player_index].empty?
      # player is playing a card
      card = user_input
      
      # ensure that the card is in their inventory
      return false unless config[:player_hands][current_player_index].any? { |player_card| player_card == card }

      # ensure that the card is actually playable
      config[:first_suit_played] ||= card.suit
      playable_cards = get_playable_cards(config[:player_hands][current_player_index])
      # TODO: add a message here?
      return false unless playable_cards.include? card
      
      # actually play the card
      config[:cards_in_play][current_player_index] = config[:player_hands][current_player_index].delete(card)

      set_winner_card_index(current_player_index) # is this correct...
      # check to see if all players have played a card
      if all_players_played_a_card?
        add_waiting_info(config[:winner_index], 'Clear')
      else
        # set next player to play a card
        next_up = next_player_index(current_player_index)
        add_waiting_info(next_up, "Play")
      end
    end
    
    save_state config 
  end

  def set_winner_card_index(index)
    # all cards played?
    #if config[:cards_in_play].size == config[:players].size
    highest_card = get_highest_card(config[:cards_in_play], config[:first_suit_played], config[:trump_card], index+1)
    config[:winner_index] = config[:cards_in_play].find_index(highest_card)
  end

  # clear the table of cards and calculate who won the trick/game
  def clear_table user_id
    return false unless player_up?(user_id)
    current_player_index = player_index(user_id)

    # determine who won the trick
    # TODO: test if this index value is correct 
    winner_index = config[:winner_index]
    config[:tricks_taken][winner_index] ||= []
    config[:tricks_taken][winner_index].push config[:cards_in_play]

    # reset variables
    config[:winner_index] = nil
    config[:cards_in_play] = []
    config[:first_suit_played] = nil
    

    # check to see if we're done with this round
    if config[:player_hands].first.empty?
      # increment rounds played
      config[:rounds_played] += 1

      # determine scores
      config[:bids].each_with_index do |bid, i|
        tricks = config[:tricks_taken][i] || []
        if tricks.size < config[:bids][i]
          player_score = tricks.size - config[:bids][i]
        elsif tricks.size > config[:bids][i]
          player_score = tricks.size
        else
          player_score = tricks.size + 10
        end
        config[:score][i] ||= []
        config[:score][i].push player_score
      end
      
      # check to see if that was the last round (game over)
      if config[:rounds_played] == config[:total_rounds]
        # game is over, determine who won
        # winners list is necessary since there can be ties
        config[:winners] = []
        highest_score = nil
        config[:score].each_with_index do |score, i|
          player_score = score.inject :+ # add up score from each round
          if highest_score.nil? || player_score >= highest_score
            # clear winners list if there's a new high score
            config[:winners].clear if highest_score.present? && player_score > highest_score
            # set new high score and record as winner
            highest_score = player_score
            config[:winners].push config[:players][i]
          end
        end
      else
        set_new_dealer
        deal_cards
      end
    else
      add_waiting_info(winner_index, "First")
    end

    save_state 
  end

  def config
    @config ||= load_state
  end
  # TODO: make this a db:JSON field for easier reference, remove config
  def load_state
    return YAML.load(self.state)
  end
  def save_state new_state = config
    self.state = new_state.to_yaml
    self.save
  end

  def get_highest_card cards, first_suit_played, trump, start_index
    return cards.first if cards.size <= 1

    # if trump was played, ignore other cards
    # an ace indicates no trump, so ignore it if that's the case
    trump_cards = (trump.value_name =~ /ace/i) ? [] : cards.compact.select { |c| c.suit == trump.suit }

    # if trump wasn't played or there is no trump (ace),
    # only cards that are the same suit as the first card played matter
    same_suit_cards = cards.compact.select { |c| c.suit == first_suit_played }
    card_set = trump_cards.empty? ? same_suit_cards : trump_cards
    
    # now simply get the highest card left
    return card_set.max
    #iterate_through_list_with_start_index(start_index, card_set) do |card|
    #  return card if card.value == highest_value
    #end
  end
  
  def get_playable_cards cards # for a players hand
    first_suit = config[:first_suit_played]
    # player can play any card if they are the first to play a card
    # or if they only have a single card left
    return cards if first_suit.nil? || cards.size == 1
    # player must play the same suit as the first card played
    playable_cards = cards.select { |card| card.suit == first_suit }
    # if player doesn't have any of the same suit as the first card played
    # they can play any card
    playable_cards = cards if playable_cards.empty?
    return playable_cards
  end

  def iterate_through_list_with_start_index start_index, list
    # start_index is relative to player seat - different for each user
    list.size.times do |offset|
      index = (start_index + offset) % list.size
      @player_index = offset
      yield list[index], index
    end
  end

  # returns the index of the next player
  def next_player_index(current_index)
    (current_index + 1) % config[:players].size
  end

  def get_next_player current_player 
    # aka: next up from config[:waiting_on]
    next_up = next_player_index(players.find_index(current_player))
    return players[next_up]
  end

  # returns true if the input array is the same size as the number of
  # players we have, and doesn't include nil
  def player_size_and_nil_check arr
    all_players = config[:players].size
    return arr.present? && (arr.compact.size == all_players)
  end

  # return true or false if we're done bidding
  # done bidding if there are the same number of valids bids
  # as there are players in the game
  def done_bidding? 
    return player_size_and_nil_check(config[:bids])
  end

  def all_players_played_a_card?
    return player_size_and_nil_check(config[:cards_in_play])
  end
end

class Card
  include Comparable
  
  SUITS = %w{Spades Hearts Diamonds Clubs}
  attr_accessor :suit, :value, :playable

  # create a single card
  def initialize suit, value
    raise 'Invalid card suit' unless SUITS.include? suit
    raise 'Invalid card value' unless value.to_i >= 0 && value.to_i < 13
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
    return 0 if @value.nil? && other.value.nil?
    return 1 if other.value.nil?
    return -1 if @value.nil?
    @value.to_i <=> other.value.to_i
  end

  def == other
    return false if other.nil?
    return false if (@value.nil? || other.value.nil?) && @value != other.value
    return (@value.to_i == other.value.to_i && @suit == other.suit)
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
    raise 'Invalid player name' if name.nil? || name.empty?
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
