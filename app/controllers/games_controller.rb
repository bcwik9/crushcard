class GamesController < ApplicationController
  require 'action_view'
  require 'action_view/helpers'
  include ActionView::Helpers::DateHelper

  before_action :set_game, except: [:index, :new, :create]

  def default_url_options(options = {})
    if params[:debug]
      { debug: true } 
    else
      {}
    end
  end

  def morph
    morph_to = params[:index].to_i
    new_id = @game.config[:players][morph_to]
    session[:id] = new_id
    @_current_user = new_id
    show
  end

  def player_up?
    @game.player_up?(@_current_user)
  end

  def invalid_user?
    !player_up?
  end

  def expected_user
    return nil unless @game.config.try(:[],:players).present?
    expected_user = @game.config[:players].index(@game.config[:waiting_on])
    expected_user = @game.config[:names][expected_user]
    expected_user
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
    if @game.config[:players].size >= Game::MAX_PLAYERS
      redirect_to @game, notice: 'There are too many players in the game already'
      true
    else
      false
    end
  end

  def add_cpu_player

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
      show
    else
      render json: { message: 'Failed to join the game' }
    end
  end

  def start
    error = nil
    if !@game.enough_players?
      error = "Must have between #{Game::MIN_PLAYERS} and #{Game::MAX_PLAYERS} players to start"
    elsif @game.config[:cards_in_play].nil?
      @game.deal_cards
      @notice = "Game has started!"
    else
      error = 'Game has already started'
    end

    if error
      render json: {message: error}
    else
      show
    end
  end

  def deal
    if @game.clear_table(@_current_user)
      show
    else
      render json: {message: "You are not the dealer"}
    end
  end

  def player_action
    error = nil

    if invalid_user?
      error = "It's not your turn, waiting for \"#{expected_user}\""
    elsif @game.config[:waiting_on_reason] == "Clear"
      error = "Waiting for next hand." 
    elsif params[:bid]
      if @game.done_bidding?
        error = 'Bidding is over'
      elsif !@game.bid_in_range?(params[:bid]) 
        error = "Bid must be between 0 and #{@game.num_cards_per_player}"
      elsif @game.invalid_dealer_bid?(@_current_user, params[:bid])
        error = "Can bid anything BUT #{params[:bid]}" 
      elsif @game.player_action(@_current_user, params[:bid])
        @notice = "Placed bid!"
      else
        @error = "Could not place bid, please try refreshing the page"
      end
    else
      card = Card.new(params[:suit], params[:value])
      if @game.player_action(@_current_user, card)
        @notice = "Played card!"
      else
        error = "You must follow the first suit played: \"#{@game.config[:first_suit_played]}\""
      end
    end

    if error.present?
      render json: { message: error }
    else
      show
    end
  end

  # GET /games
  # GET /games.json
  def index
    @games = Game.all
  end

  # GET /games/1
  # GET /games/1.json
  def is_playing?
    @is_playing ||= @game.config[:players].include?(@_current_user) 
  end

  def current_user_name
    if is_playing?
      i = @game.config[:players].index(@_current_user)
      @game.config[:names][i]
    else 
      "ANONYMOUS"
    end
  end

  def show
    # Refresh game in memory after commiting action
    @game = Game.find(@game.id) if params[:action] != 'show'

    @board_updated = if params[:updated].nil? # hard page hit - from browser
                       true
                     else
                       last_update = DateTime.parse(params[:updated])
                       #updated = @game.updated_at > last_update
                       updated = (@game.updated_at - last_update) > 0.99 # ignore milisecond rounding errors
                       updated
                     end

    if @board_updated
      @enough_players = @game.enough_players?
  
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
        @places[i] = @total_scores.select{|t| t > score}.count + 1
      end
      
      # players hand
      @cards = []
      if is_playing?
        @cards = @game.config[:player_hands][player_index] || @cards
      end
      @cards.sort! { |a,b| a.suit_order b }

      # cards that have been played
      @played_cards = @game.config[:cards_in_play] || []
      if @game_started
        # display cards in different order since the user is on the bottom
        @played_cards = []
        @game.iterate_through_list_with_start_index(player_index, @game.config[:players]) do |player,i|
          @played_cards.push @game.config[:cards_in_play][i]
        end
      end
  
  
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
      if @waiting_on_you && @game.config[:waiting_on_chime]
        @game.config[:waiting_on_chime] = nil
        @game.save_state
        @chime = true
      end
    
      # show ace of spades if game hasnt started
      @trump = @game.config[:trump_card] # || Card.new('Spades', 12)
  
      @poll = !@game_started # waiting room - everyone is waiting for updates
      @poll = !@waiting_on_you unless @poll
    end

    js_data = if request.xhr? && @board_updated
                { html: json_board }
              else
                nil
              end

    if request.xhr? 
      render :json => js_data 
    else
      render 'show'
    end
  end

  def json_board
    render_to_string(partial: "board_info", formats: ["html"])
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

  def create
    @game = Game.new(game_params)
    @game.set_up(game_options)

    if @game.save
      redirect_to game_path(@game), notice: 'New game was successfully created. Copy and share this URL with your friends.'
    else
      new
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

    def game_options
      params.permit(*Game::OPTIONS.keys).to_h
    end
end
