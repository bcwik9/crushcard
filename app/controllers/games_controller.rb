class GamesController < ApplicationController
  require 'action_view'
  require 'action_view/helpers'
  include ActionView::Helpers::DateHelper

  before_action :set_game, only: [:show, :edit, :update, :destroy]

  def add_cpu_player
    set_game
    state = @game.load_state

    if state[:cards_in_play]
      redirect_to @game, notice: "Can't join once the game has already started"
    elsif state[:players].size >= 5
      redirect_to @game, notice: 'There are too many players in the game already'
    else
      state[:players].push SecureRandom.uuid()

      name = 'cpu'
      while state[:names].include? name
        name += 'u'
      end
      state[:names].push name

      @game.save_state state
      if @game.save
        redirect_to @game, notice: 'Joined the game!'
      else
        redirect_to @game, notice: 'Failed to join the game'
      end
    end
  end

  def add_player
    if @_current_user.nil?
      redirect_to @game, notice: 'Unable to determine current user'
      return
    end

    set_game
    state = @game.load_state

    if state[:cards_in_play]
      redirect_to @game, notice: 'Cant join once the game has already started'
    elsif state[:players].size >= 5
      redirect_to @game, notice: 'There are too many players in the game already'
    elsif state[:players].include?(@_current_user)
      redirect_to @game, notice: "You're already in the game"
    else
      state[:players].push @_current_user

      while state[:names].include? params[:username]
        # make sure username is unique by appending random numbers
        params[:username] += rand(10).to_s
      end
      state[:names].push params[:username]

      @game.save_state state
      if @game.save
        redirect_to @game, notice: 'Joined the game!'
      else
        redirect_to @game, notice: 'Failed to join the game'
      end
    end
  end

  def deal
    set_game
    state = @game.load_state
    if state[:players].size < 3 || state[:players].size > 5
      redirect_to @game, notice: 'Must have between 3 and 5 players to start'
      return
    end
    if state[:cards_in_play].nil?
      @game.save_state @game.deal_cards(state)
      @game.save
      redirect_to @game, notice: 'Game has started!'
    else
      redirect_to @game, notice: 'Game has already started'
    end
  end

  def player_action
    set_game
    state = @game.load_state

    # player isnt allowed to do anything if it's not their turn
    if state[:waiting_on] != @_current_user
      redirect_to @game, notice: "It's not your turn"
      return
    end
    
    if params[:bid]
      # user is making a bid
      if @game.done_bidding? state
        redirect_to @game, notice: 'Bidding is over'
        return
      else
        if @game.player_action(@_current_user, params[:bid])
          @game.save
          redirect_to @game, notice: 'Placed bid!'
        else
          redirect_to @game, notice: "Can bid anything BUT #{params[:bid]}"
        end
      end
    else
      # user is playing a card
      card = Card.new(params[:suit], params[:value])
      if @game.player_action(@_current_user, card)
        @game.save
        redirect_to @game, notice: "Played a card!"
      else
        redirect_to @game, notice: "Nice try, but you have to play a #{state[:first_suit_played].chop.downcase}"
      end
    end
  end

  # GET /games
  # GET /games.json
  def index
    @games = Game.all
  end

  # GET /games/1
  # GET /games/1.json
  def show
    state = @game.load_state
    
    @is_playing = state[:players].include?(@_current_user)
    @can_start_game = state[:players].first == @_current_user
    @game_started = !state[:bids].nil?
    @winners = state[:winners].map{|player| state[:names][state[:players].index(player)] } rescue nil
    player_index = state[:players].index(@_current_user) || 0

    # round number
    @round = state[:total_rounds] - state[:rounds_played]

    # names/scores around the board
    # add in different order so the user is always on the bottom
    @names = []
    @total_scores = []
    @round_scores = []
    @game.iterate_through_list_with_start_index(player_index, state[:names]) do |name, i|
      bid_avail = state[:bids] && state[:bids][i]
      tricks_taken = (state[:tricks_taken] && state[:tricks_taken][i]) ? state[:tricks_taken][i].size : 0
      bid = bid_avail ? state[:bids][i] : 'N/A'
      score = 0
      if state[:score] && state[:score][i]
        score = state[:score][i].inject :+
      end
      bid_info = name.nil? ? nil : "Taken/Bid: #{tricks_taken} of #{bid}" 
      @names.push name
      @total_scores.push score
      @round_scores.push bid_info
    end

    @places = []
    @total_scores.each_with_index do |score, i|
      @places[i] = @total_scores.select{|t| t > i}.count + 1
    end
    
    # cards that have been played
    @played_cards = state[:cards_in_play] || []
    if @game_started
      # display cards in different order since the user is on the bottom
      @played_cards = []
      @game.iterate_through_list_with_start_index(player_index, state[:players]) do |player,i|
        @played_cards.push state[:cards_in_play][i]
      end
    end

    # players hand
    @cards = []
    if @is_playing
      @cards = state[:player_hands][player_index] || @cards

      # can't play any cards unless it's your turn
      playable_cards = []
      if state[:waiting_on] == @_current_user
        playable_cards = @game.get_playable_cards(state[:first_suit_played], @cards)
      end
      @cards.each do |card|
        if playable_cards.include? card
          card.playable = true
        end
      end
    end
    @cards.sort! { |a,b| a.suit_order b }

    # game status (ie. who we're waiting on)
    if state[:waiting_on]
      waiting_on_index = state[:players].index(state[:waiting_on])
      @waiting_on = waiting_on_index ? state[:names][waiting_on_index] : "Table to clear"
      @waiting_on = 'YOU' if @_current_user == state[:waiting_on]
      @done_bidding = @game.done_bidding? state
      unless @done_bidding
        @waiting_on += " (BIDDING)"
      end
    else
      @waiting_on = 'Game to start'
    end
  
    # show ace of spades if game hasnt started
    @trump = state[:trump_card] || Card.new('Spades', 12)
    
    # make sure show.js.erb is executed in the views folder
    respond_to do |format|
      format.js
      format.html
    end
  end

  # GET /games/new
  def new
    @game = Game.new
  end

  # GET /games/1/edit
  def edit
  end

  # POST /games
  # POST /games.json
  def create
    @game = Game.new(game_params)
    @game.set_up

    respond_to do |format|
      if @game.save
        format.html { redirect_to @game, notice: 'Game was successfully created.' }
        format.json { render :show, status: :created, location: @game }
      else
        format.html { render :new }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /games/1
  # PATCH/PUT /games/1.json
  def update
    respond_to do |format|
      if @game.update(game_params)
        format.html { redirect_to @game, notice: 'Game was successfully updated.' }
        format.json { render :show, status: :ok, location: @game }
      else
        format.html { render :edit }
        format.json { render json: @game.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /games/1
  # DELETE /games/1.json
  def destroy
    @game.destroy
    respond_to do |format|
      format.html { redirect_to games_url, notice: 'Game was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_game
      @game = Game.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def game_params
      params.require(:game).permit(:name, :state)
    end
end
