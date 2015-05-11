class Game < ActiveRecord::Base
  require 'yaml'
  after_initialize :state_data
  before_save :serialize_state

  def enough_players?
    state_data[:player].size > 2 && state_data[:player].size <= 5
  end

  def has_player?(player_id)
    state_data[:player].has_key?(player_id)
  end

  def serialize_state
    self.state = state_data.to_yaml
  end

  def can_deal?(player_id)
    state_data[:creator] == player_id
  end

  def needs_to_bid?(current_user)
    raise "Not a player in this game" unless has_player? current_user
  end

  def waiting_for_players?
    state_data[:current_status] == :waiting_for_players && state_data[:player].size < 5
  end

  def add_player(player_id, player_name)
    raise "Cant add an already added player" if has_player?(player_id)
    state_data[:players] << player_id 
    # make a unique name if it is already taken
    while state_data[:player].values.include? player_name
      player_name += rand(10).to_s
    end
    state_data[:player][player_id] = player_name
    save!
    player_name
  end

  def deal_cards
    return unless enough_players?
    state_data[:deck] = (0..51).to_a.shuffle
    dealer_index = state_data[:rounds_played] % state_data[:player].size
    state_data[:dealer] = state_data[:players][dealer_index]

    # person to the 'left' of the dealer bids first
    state_data[:bids] = []
    state_data[:waiting_on] = get_next_player state_data[:dealer], state_data[:players]

    # deal cards first to player on 'right' of dealer
    state_data[:player_hands] = Hash.new
    num_cards_per_player = state_data[:total_rounds] - state_data[:rounds_played]
    iterate_through_list_with_start_index(state_data[:players].find_index(state_data[:waiting_on]), state_data[:players]) { |player, i|
      state_data[:player_hands][i] = state_data[:deck].slice!(0..(num_cards_per_player-1))
    }

    # the next card in the deck is trump
    # whatever suit is trump is valued higher than non-trump suits
    # an Ace as trump means there is "no trump"
    state_data[:trump_card] = state_data[:deck].slice! 0

    # set a few default values
    state_data[:cards_in_play] = []
    state_data[:tricks_taken] = []
    state_data[:current_status] = :in_play
    save!
  end

  def set_top_bidding_player_next
    iterate_through_list_with_start_index(@current_player_index+1, state_data[:bids]) do |bid,i|
      if state_data[:bids].max == bid
        state_data[:waiting_on] = state_data[:players][i] # found it
        return
      end
    end
  end

  def playable_card?(card)
    return false unless state_data[:player_hands][@current_player_index].include? card

    first_card_suit = state_data[:cards_in_play].empty? ? nil : card_suit(state_data[:cards_in_play].first)
    return true unless first_card_suit
    first_card_suit == card_suit(card)
  end
=begin
        state_data[:waiting_on] = 

          get_next_player state_data[:waiting_on], state_data[:players]
=end

  def player_action(player_id, user_input=nil)
    # return false if it's not the players turn
    return false if player_id != state_data[:waiting_on]
    @current_player_index = current_player_index = state_data[:players].find_index(player_id)
    cards_remaining_in_hand = !state_data[:player_hands][current_player_index].empty?

    case true 
    when !done_bidding?
      bid = user_input.to_i
      # dealer cannot bid the same amount as the number of cards dealt
      total_bid_value = state_data[:bids].select { |bid| !bid.nil? }.inject(:+)
      num_cards_per_player = state_data[:total_rounds] - state_data[:rounds_played]
      invalid_bid_amount = total_bid_value + bid == num_cards_per_player
      is_dealer = state_data[:dealer] == player_id
      return false if is_dealer && invalid_bid_amount
      state_data[:bids][current_player_index] = bid
      if is_dealer # dealer bids last
        set_top_bidding_player_next
      end
    when cards_remaining_in_hand
      card = user_input.to_i
      return false unless playable_card?(card)
      state_data[:cards_in_play] << state_data[:player_hands][current_player_index].delete(card)
      if all_players_played_a_card?
        # make sure nobody can do anything
        state_data[:waiting_on] = "Table to clear"
        delay.clear_table
      else
        # set next player to play a card
        state_data[:waiting_on] = get_next_player state_data[:waiting_on], state_data[:players]
      end
    end

    save!
  end

  def state_data
    current_time = self.updated_at || self.created_at 
    @state_read_at ||= current_time
    if @state_data.nil? || (@state_read_at && current_time > @state_read_at)
      if self.state.nil?
        self.state = { 
          current_status: :waiting_for_players, 
          total_rounds: 10,
          rounds_played: 0,
          players: nil,
          player_hands: nil,
          score: nil,
          deck: nil
        }.to_yaml 
      end
      @state_data = load_state
      @state_data[:player] ||= Hash.new
      @state_data[:players] ||= Array.new # this is the Order of players 
      @state_data[:score] ||= Array.new
    end
    @state_data
  end

  # clear the table of cards and calculate who won the trick/game
  def clear_table
    sleep 3
    highest_card = get_highest_card
    winner_index = state[:cards_in_play].find_index(highest_card)
    state_data[:tricks_taken][winner_index] ||= []
    state_data[:tricks_taken][winner_index] << state_data[:cards_in_play]
    state_data[:cards_in_play] = []
    state_data[:rounds_played] += 1

    if state_data[:player_hands].first.empty? # this is bad database transactions? TODO
      state_data[:tricks_taken].each_with_index do |tricks, i|
        num_tricks_taken = tricks.nil? ? 0 : tricks.size
        if num_tricks_taken < state_data[:bids][i]
          player_score = num_tricks_taken - state_data[:bids][i]
        elsif num_tricks_taken > state_data[:bids][i]
          player_score = num_tricks_taken
        else
          player_score = num_tricks_taken + 10
        end
        state_data[:score][i] ||= []
        state_data[:score][i].push player_score
      end

      # check to see if that was the last round (game over)
      if state_data[:rounds_played] == state_data[:total_rounds]
        # game is over, determine who won
        state_data[:winners] = []
        highest_score = nil
        state_data[:score].each_with_index do |score, i|
          player_score = score.inject :+ # add up score from each round
          if highest_score.nil? or player_score >= highest_score
            highest_score = player_score
            # clear winners list if there's a new high score
            # winners list is necessary since there can be ties
            state_data[:winners].clear if player_score > highest_score
            state_data[:winners].push state_data[:players][i]
          end
        end
        # TODO: implement something to notify game has ended and who won
      else
        # deal cards for the next round
        deal_cards
      end
    else
      # winner is the first to play a card next
      state_data[:waiting_on] = state_data[:players][winner_index]
    end

    save_state
    self.save!
  end

  def load_state
    return self.state.nil? ? Hash.new : YAML.load(self.state)
  end

  def save_state(state = state_data)
    self.state = state.to_yaml
  end

  def get_highest_card 
    cards = state_data[:cards_in_play]

    trump = state_data[:trump_card]
    scoring_cards = cards.select { |c| card_suit(c) == card_suit(trump) } if trump < 12
    scoring_cards = cards.select { |c| card_suit(c) == card_suit(cards.first) } if scoring_cards.empty?
    return scoring_cards.max
  end

  def card_suit(card)
    card % 4
  end

  def get_playable_cards cards
    first_suit = if first_card = state_data[:cards_in_play].try(:first)
                   card_suit(first_card)
                 else
                   nil
                 end
    return cards if first_suit.nil? # Anything goes

    playable_cards = cards.select { |card| card_suit(card) == first_suit }
    playable_cards = cards if playable_cards.empty?
    playable_cards
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
  def player_size_and_nil_check arr
    arr.size == state_data[:players].size && !arr.include?(nil)
  end

  # return true or false if we're done bidding
  # done bidding if there are the same number of valids bids
  # as there are players in the game
  def done_bidding?
    return player_size_and_nil_check(state_data[:bids])
  end

  def all_players_played_a_card?
    return player_size_and_nil_check(state_data[:cards_in_play])
  end
end
