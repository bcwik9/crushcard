class GamesController < ApplicationController
  include ActionController::Live

  before_action :set_game, only: [:show, :edit, :update, :destroy]

  # GET /games
  # GET /games.json
  def index
    @games = Game.all


    # Set the response header to keep client open
    response.headers['Content-Type'] = 'text/event-stream'
    
    # .. list of users who are current streaming the list
    #list_of_current_streamers = Users.streamers
    
    # loop infinitely, users can just close the browser
    begin
      loop do
        # .. iterate over the list and send the list of users.
        names = %w[ben tracey bob]
        # build the package to send over the stream using 
        # Server-Sent Events protocol format.
        response.stream.write "id: 0\n"
        response.stream.write "event: update\n"
        # two new lines marks the end of the data for this event.
        response.stream.write "data: #{JSON.dump(names)}\n\n"
        
        # decided to only send it ever 2 seconds.
        sleep 2
      end
    rescue IOError
      # client disconnected.
      # .. update database streamers to remove disconnected client
    ensure
      # clean up the stream by closing it.
      response.stream.close
    end
  end

  # GET /games/1
  # GET /games/1.json
  def show
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
      params[:game]
    end
end
