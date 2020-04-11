class GamesController < ApplicationController
  require 'action_view'
  require 'action_view/helpers'
  include ActionView::Helpers::DateHelper

  before_action :set_game, only: [:show, :edit, :update, :destroy]

  def invalid_user?
    inv = @game.config[:waiting_on] != @_current_user
    #puts "\nINVALID USER: #{inv} :::: #{@game.config[:waiting_on]} != #{@_current_user}\n".red
    inv
  end

  def already_started?
    if @game.config[:cards_in_play]
      redirect_to @game, notice: "Can't join once the game has already started"
      true
    else
      false
    end
  end

  def too_many_players?
    if @game.config[:players].size >= 5
      redirect_to @game, notice: 'There are too many players in the game already'
      true
    else
      false
    end
  end

  def add_cpu_player
    set_game

    return if already_started?
    return if too_many_players?

    @game.config[:players].push SecureRandom.uuid()

    name = 'cpu'
    while @game.config[:names].include? name
      name += 'u'
    end
    @game.config[:names].push name

    if @game.save_state
      redirect_to @game, notice: 'Joined the game!'
    else
      redirect_to @game, notice: 'Failed to join the game'
    end
  end

  def add_player
    set_game

    if @_current_user.nil?
      redirect_to @game, notice: 'Unable to determine current user'
      return
    end
    return if already_started?
    return if too_many_players?
    if @game.config[:players].include?(@_current_user)
      redirect_to @game, notice: "You're already in the game"
      return
    end

    @game.config[:players].push @_current_user
    if @game.config[:players].size == 1 # first to join is first dealer
      @game.config[:waiting_on] = @_current_user
    end
    while @game.config[:names].include? params[:username]
      # make sure username is unique by appending random numbers
      params[:username] += rand(10).to_s
    end
    @game.config[:names].push params[:username]

    if @game.save_state
      redirect_to @game, notice: 'Joined the game!'
    else
      redirect_to @game, notice: 'Failed to join the game'
    end
  end

  def deal
    set_game
    if @game.config[:players].size < 3 || @game.config[:players].size > 5
      redirect_to @game, notice: 'Must have between 3 and 5 players to start'
      return
    end
    if @game.config[:cards_in_play].nil?
      @game.deal_cards
      redirect_to @game, notice: 'Game has started!'
    else
      redirect_to @game, notice: 'Game has already started'
    end
  end

  def player_action
    set_game
    # player isnt allowed to do anything if it's not their turn
    if invalid_user?
      redirect_to @game, notice: "It's not your turn"
      return
    end
    
    if params[:bid]
      # user is making a bid
      if @game.done_bidding?
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
        show
      else
        redirect_to @game, notice: "Nice try, but you have to play a #{@game.config[:first_suit_played].chop.downcase}"
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
    @board_updated = if params[:updated].nil? # hard page hit - from browser
                       true
                     else
                       last_update = DateTime.parse(params[:updated])
                       #updated = @game.updated_at > last_update
                       updated = (@game.updated_at - last_update) > 0.3 # ignore partial second rounding errors
                       updated
                     end

    if @board_updated
      @is_playing = @game.config[:players].include?(@_current_user)
      @enough_players = @game.config[:players].compact.size >= 3
  
      # TODO: game @game.config machine - waiting-for-palyers, waiting-to-deal, bidding
  
      @dealt = @game.config[:player_hands].present?
      @game_started = !@game.config[:bids].nil?
      @can_start_game = (!@game_started) && @game.config[:players].first == @_current_user && @enough_players # can deal
  
      @winners = @game.config[:winners].map{|player| @game.config[:names][@game.config[:players].index(player)] } rescue nil
      player_index = @game.config[:players].index(@_current_user) || 0
  
      # round number
      @round = @game.config[:total_rounds] - @game.config[:rounds_played]
  
      # names/scores around the board
      # add in different order so the user is always on the bottom
      @names = []
      @indexes = []
      @game.iterate_through_list_with_start_index(player_index, @game.config[:players]) do |user_id, i|
        @indexes.push @game.config[:players].index(user_id)
      end
      
      @total_scores = []
      @round_scores = []
      @game.iterate_through_list_with_start_index(player_index, @game.config[:names]) do |name, i|
        bid_avail = @game.config[:bids] && @game.config[:bids][i]
        tricks_taken = (@game.config[:tricks_taken] && @game.config[:tricks_taken][i]) ? @game.config[:tricks_taken][i].size : 0
        tricks_taken = "??" unless bid_avail
        bid = bid_avail ? @game.config[:bids][i] : '??'
        score = 0
        if @game.config[:score] && @game.config[:score][i]
          score = @game.config[:score][i].sum
        end
        bid_info = "Taken #{tricks_taken} / #{bid} Bid" 
        bid_color = if (!bid_avail) || tricks_taken == bid
                      :white
                    else
                      bid > tricks_taken ? :red : :yellow
                    end
        @names.push name
        @total_scores.push score
        @round_scores.push [bid_info, bid_color]
      end
  
      @places = []
      @total_scores.each_with_index do |score, i|
        @places[i] = @total_scores.select{|t| t > i}.count + 1
      end
      
      # cards that have been played
      @played_cards = @game.config[:cards_in_play] || []
      if @game_started
        # display cards in different order since the user is on the bottom
        @played_cards = []
        @game.iterate_through_list_with_start_index(player_index, @game.config[:players]) do |player,i|
          @played_cards.push @game.config[:cards_in_play][i]
        end
      end
  
      # players hand
      @cards = []
      if @is_playing
        @cards = @game.config[:player_hands][player_index] || @cards
  
        # can't play any cards unless it's your turn
        playable_cards = []
        playable_cards = @game.get_playable_cards(@cards) unless invalid_user?
  
        @cards.each do |card|
          if playable_cards.include? card
            card.playable = true
          end
        end
      end
      @cards.sort! { |a,b| a.suit_order b }
  
      # game status (ie. who we're waiting on)
      @done_bidding = @game.done_bidding?
      if @game.config[:waiting_on_index] 
        @waiting_on_index = @game.config[:waiting_on_index]
        @waiting_on = if @waiting_on_index 
                        @game.config[:waiting_on_reason]
                      else
                        "Table to clear" # TODO: move into game
                      end
      end
      @waiting_on_you = @waiting_on_index == @indexes[0] # seat 0 is the up-next user?
    
      # show ace of spades if game hasnt started
      @trump = @game.config[:trump_card] # || Card.new('Spades', 12)
  
      @poll = !@game_started # waiting room - everyone is waiting for updates
      @poll = !@waiting_on_you unless @poll
    end

    js_data = if request.format == "json" && @board_updated
                { html: render_to_string(partial: "board_info", formats: ["html"]) }
              else
                nil
              end

    respond_to do |format|
      format.html
      format.json { 
        render :json => js_data 
      }
    end
  end

  def seat_index_for_player(player_id)
    return 0 if @game.config[:players].nil? || @game.config[:players].size < 1

    player_index = @game.config[:players].index(@_current_user) || 0 

    seat_index = 0
    @game.iterate_through_list_with_start_index(player_index, @game.config[:players]) do |player,i|
      if player == player_id
        seat_index = i 
        break
      end
    end
    seat_index
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
        format.html { redirect_to @game, notice: 'New game was successfully created. Copy and share this URL with your friends.' }
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
