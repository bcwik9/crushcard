class GamesController < ApplicationController
  before_action :set_game, only: [:show, :edit, :update, :destroy]

  def add_player
    unless @_current_user.nil?
      set_game
      state = @game.load_state
      if state[:players].size < 5
        unless state[:players].include?(@_current_user)
          if state[:cards_in_play]
            redirect_to @game, notice: 'Cant join once the game has already started'
            return
          end
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
        else
          redirect_to @game, notice: 'Youre already in the game'
        end
      else
        redirect_to @game, notice: 'There are too many players in the game already'
      end
    end
  end
  
  def deal
    set_game
    state = @game.load_state
    if state[:players].size < 3 or state[:players].size > 5
      redirect_to @game, notice: 'Must have between 3 and 5 players to start'
      return
    end
    if state[:players].first == @_current_user
      if state[:cards_in_play].nil?
        @game.save_state @game.deal_cards(state)
        @game.save
        redirect_to @game, notice: 'Game has started!'
      else
        redirect_to @game, notice: 'Game has already started'
      end
    else
      redirect_to @game, notice: 'Only the creator of the game can start it'
    end
  end

  def player_action
    set_game
    state = @game.load_state

    # player isnt allowed to do anything if it's not their turn
    if state[:waiting_on] != @_current_user
      redirect_to @game, notice: "Dude... It's not your turn"
      return
    end
    
    if params[:bid]
      # user is making a bid
      if @game.done_bidding? state
        redirect_to @game, notice: 'Bidding is over BRO'
        return
      else
        if @game.player_action(@_current_user, params[:bid])
          @game.save
          redirect_to @game, notice: 'Placed bid, YEAAA!'
        else
          redirect_to @game, notice: "Can bid anything BUT #{params[:bid]}"
        end
      end
    else
      # user is playing a card
      card = Card.new(params[:suit], params[:value])
      if @game.player_action(@_current_user, card)
        @game.save
        redirect_to @game, notice: "Played a card, niceee!"
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
    
    is_playing = state[:players].include?(@_current_user)
    game_started = !state[:bids].nil?
    player_index = state[:players].index(@_current_user) || 0

    # round number
    @round = state[:total_rounds] - state[:rounds_played]

    # names/scores around the board
    # add in different order so the user is always on the bottom
    @names = []
    @round_scores = []
    @game.iterate_through_list_with_start_index(player_index, state[:names]) do |name, i|
      tricks_taken = (state[:tricks_taken] and state[:tricks_taken][i]) ? state[:tricks_taken][i].size : 0
      bid = (state[:bids] and state[:bids][i]) ? state[:bids][i] : 'No bid yet'
      score = 0
      if state[:score] and state[:score][i]
        score = state[:score][i].inject :+
      end
      @names.push name
      @round_scores.push (name.nil?) ? nil : "Tricks taken: #{tricks_taken} | Bid: #{bid} | Score: #{score}"
    end
    
    # cards that have been played
    @played_cards = state[:cards_in_play]
    if game_started
      # display cards in different order since the user is on the bottom
      @played_cards = []
      @game.iterate_through_list_with_start_index(player_index, state[:players]) do |player,i|
        @played_cards.push state[:cards_in_play][i]
      end
    end

    # players hand
    @cards = []
    if is_playing
      @cards = state[:player_hands][player_index] || @cards

      # can't play any cards unless it's your turn
      playable_cards = []
      if state[:waiting_on] == @_current_user
        playable_cards = @game.get_playable_cards(state[:first_suit_played], state[:player_hands][player_index])
      end
      @cards.each do |card|
        if playable_cards.include? card
          card.playable = true
        end
      end
    end
    
    # game status (ie. who we're waiting on)
    if state[:waiting_on]
      waiting_on_index = state[:players].index(state[:waiting_on])
      @waiting_on = state[:names][waiting_on_index]
      @waiting_on = 'YOU' if @_current_user == state[:waiting_on]
      unless @game.done_bidding? state
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
