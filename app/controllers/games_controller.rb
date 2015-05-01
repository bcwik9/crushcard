class GamesController < ApplicationController
  before_action :set_game, only: [:show, :edit, :update, :destroy]

  def add_player
    unless @_current_user.nil?
      set_game
      state = @game.load_state
      if state[:players].size < 5
        unless state[:players].include?(@_current_user)
          if state[:cards_in_play]
            redirect_to @game, notice: 'Cant join once game has already started'
            return
          end
          state[:players].push @_current_user
          @game.save_state state
          if @game.save
            redirect_to @game, notice: 'Joined the game!'
          else
            redirect_to @game, notice: 'Failed to join the game'
          end
        else
          redirect_to @game, notice: 'Player is already in game'
        end
      else
        redirect_to @game, notice: 'There are too many players in the game already'
      end
    end
  end
  
  def deal
    set_game
    state = @game.load_state
    # game must have at least 3 players to start
    if state[:players].size < 3
      redirect_to @game, notice: 'Must have at least 3 players to start the game'
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

  # GET /games
  # GET /games.json
  def index
    @games = Game.all
  end

  # GET /games/1
  # GET /games/1.json
  def show
    state = @game.load_state

    if state[:players].include?(@_current_user)
      player_index = state[:players].index(@_current_user)
      @cards = state[:player_hands][player_index]
    end
    
    @round = state[:total_rounds] - state[:rounds_played]

    if state[:waiting_on]
      waiting_on_index = state[:players].index(state[:waiting_on])
      current_player_index = state[:players].index(@_current_user) || 99
      @waiting_on = (waiting_on_index < current_player_index) ? "Player #{waiting_on_index + 1}" : "Player#{waiting_on_index}"
      @waiting_on = 'YOU' if @_current_user == state[:waiting_on]
      unless state[:bids].size == state[:players].size
        @waiting_on += " (BIDDING)"
      end
    else
      @waiting_on = 'Game to start'
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
