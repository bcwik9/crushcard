class GamesController < ApplicationController
  before_action :set_game, only: [:add_player, :deal, :player_action, :show, :edit, :update, :destroy]

  def add_player
    if @game.state_data[:players].size > 5
      redirect_to @game, notice: 'There are too many players in the game already'
    elsif @game.has_player?(current_user)
      redirect_to @game, notice: 'Youre already in the game'
    elsif !@game.waiting_for_players?
      redirect_to @game, notice: 'Cant join once the game has already started'
    else
      session[:player_name] = @game.add_player(current_user, params[:username])
      redirect_to @game, notice: "Welcome to the game, #{session[:player_name]}"
    end
  end

  def deal
    message = if @game.state_data[:players].size < 3 or @game.state_data[:players].size > 5
                'Must have between 3 and 5 players to start'
              elsif !@game.waiting_for_players?
                'Game has already started'
              elsif @game.can_deal?(current_user)
                'Only the creator of the game can start it'
              else
                @game.deal_cards(@game.state_data)
                @game.state_data[:current_status] = :in_play
                @game.save!
                'Game has started!'
              end
    redirect_to @game, notice: message
  end

  def player_action
    set_game
    state = @game.load_state

    # player isnt allowed to do anything if it's not their turn
    if state[:waiting_on] != current_user
      redirect_to @game, notice: "Dude... It's not your turn"
      return
    end

    if params[:bid]
      # user is making a bid
      if @game.done_bidding? state
        redirect_to @game, notice: 'Bidding is over BRO'
        return
      else
        if @game.player_action(current_user, params[:bid])
          @game.save
          redirect_to @game, notice: 'Placed bid, YEAAA!'
        else
          redirect_to @game, notice: "Can bid anything BUT #{params[:bid]}"
        end
      end
    else
      # user is playing a card
      card = Card.new(params[:suit], params[:value])
      if @game.player_action(current_user, card)
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
    is_playing = @game.state_data[:player].has_key?(current_user)
    player_index = @game.state_data[:players].index(current_user) || 0

    game_started = !@game.state_data[:bids].nil?

    # round number
    @round = @game.state_data[:total_rounds] - @game.state_data[:rounds_played]

    # names/scores around the board
    # add in different order so the user is always on the bottom
    @names = []
    @round_scores = []
    @game.iterate_through_list_with_start_index(player_index, @game.state_data[:players]) do |player_id, i|
      tricks_taken = (@game.state_data[:tricks_taken] and @game.state_data[:tricks_taken][i]) ? @game.state_data[:tricks_taken][i].size : 0
      bid = (@game.state_data[:bids] and @game.state_data[:bids][i]) ? @game.state_data[:bids][i] : 'No bid yet'
      score = 0
      if @game.state_data[:score] and @game.state_data[:score][i]
        score = @game.state_data[:score][i].inject :+
      end
      @names.push @game.state_data[:names][i]
      @round_scores.push (player_id.nil?) ? nil : "Tricks taken: #{tricks_taken} | Bid: #{bid} | Score: #{score}"
    end

    # cards that have been played
    @played_cards = @game.state_data[:cards_in_play]
    if game_started
      # display cards in different order since the user is on the bottom
      @played_cards = []
      @game.iterate_through_list_with_start_index(player_index, @game.state_data[:players]) do |player,i|
        @played_cards.push @game.state_data[:cards_in_play][i]
      end
    end

    # players hand
    @cards = []
    if is_playing && game_started
      @cards = @game.state_data[:player_hands][player_index] || @cards

      # can't play any cards unless it's your turn
      playable_cards = []
      if @game.state_data[:waiting_on] == current_user
        playable_cards = @game.get_playable_cards(@game.state_data[:first_suit_played], @game.state_data[:player_hands][player_index])
      end
      @cards.each do |card|
        if playable_cards.include? card
          card.playable = true
        end
      end
    end
    @cards.sort!

    # game status (ie. who we're waiting on)
    if @game.state_data[:waiting_on]
      waiting_on_index = @game.state_data[:players].index(@game.state_data[:waiting_on])
      @waiting_on = @game.state_data[:names][waiting_on_index]
      @waiting_on = 'YOU' if current_user == @game.state_data[:waiting_on]
      unless @game.done_bidding? @game.state_data
        @waiting_on += " (BIDDING)"
      end
    else
      @waiting_on = 'Game to start'
    end

    # show ace of spades if game hasnt started
    @trump = @game.state_data[:trump_card] || Card.new('Spades', 12)

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
    @game.state_data[:players] << current_user

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
