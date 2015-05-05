namespace :cwik do

  task :test => :environment do
    # create new game
    g = Game.new
    g.set_up
    state = g.load_state

    # add 3 players
    3.times do |i|
      state[:players].push "player_#{i}"
      state[:names].push "name_#{i}"
    end

    # deal and reload state
    g.deal_cards state
    
    puts state.to_yaml
  end
end
