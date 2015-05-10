class Game < ActiveRecord::Base
  require 'yaml'
  after_initialize :state_data
  before_save :serialize_state

  def has_player?(player_id)
    state_data[:player].has_key?(player_id)
  end

  def serialize_state
    self.state = state_data.to_yaml
  end

  def can_deal?(player_id)
    state_data[:players].first == player_id && state_data.has_key?(player_id)
  end

  def waiting_for_players?
    state_data[:current_status] == :waiting_for_players && state_data[:player].size < 5
  end

  def add_player(player_id, player_name)
    state_data[:players] << player_id 
    while state_data[:names].include? player_name
      player_name += rand(10).to_s
    end
    state_data[:names] << player_name
    state_data[:player][player_id] = player_name
    save!
    player_name
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

      # dealer cannot bid the same amount as the number of cards dealt
      total_bids = state[:bids].select { |bid| !bid.nil? }.inject(:+)
      num_cards_per_player = state[:total_rounds] - state[:rounds_played]
      if state[:dealer] == user_id and total_bids + bid == num_cards_per_player
        return false
      end

      # record the bid
      state[:bids][current_player_index] = bid

      if state[:dealer] == user_id
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
      card = user_input

      # ensure that the card is in their inventory
      return false unless state[:player_hands][current_player_index].any? { |player_card| player_card == card }

      # ensure that the card is actually playable
      state[:first_suit_played] ||= card.suit
      playable_cards = get_playable_cards(state[:first_suit_played], state[:player_hands][current_player_index])
      return false unless playable_cards.include? card

      # actually play the card
      state[:cards_in_play][current_player_index] = state[:player_hands][current_player_index].delete(card)

      # check to see if all players have played a card
      if all_players_played_a_card?(state)
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
        end
      else
        # set next player to play a card
        state[:waiting_on] = get_next_player state[:waiting_on], state[:players]
      end
    end

    save_state state
    return true
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
          deck: nil,
          names: nil
        }.to_yaml 
      end
      @state_data = load_state
      @state_data[:players] ||= Array.new
      @state_data[:names] ||= Array.new
      @state_data[:player] ||= Hash.new
    end
    @state_data
  end

  def load_state
    return self.state.nil? ? Hash.new : YAML.load(self.state)
  end

  def save_state(state = state_data)
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
  # done bidding if there are the same number of valids bids
  # as there are players in the game
  def done_bidding? state
    return player_size_and_nil_check(state[:bids], state)
  end

  def all_players_played_a_card? state
    return player_size_and_nil_check(state[:cards_in_play], state)
  end
end

