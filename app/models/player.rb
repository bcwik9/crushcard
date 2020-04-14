class Player
  # TODO: not implemented or used
  attr_accessor :name, :inventory

  def initialize name
    raise 'Invalid player name' if name.nil? || name.empty?
    @name = name
    @inventory = []
  end

  def place_bid
    raise 'TODO: implement me!' # TODO: implement this
    return 0
  end

  # play a card from the inventory
  def play_card
    raise 'TODO: implement me!' # TODO: implement this
  end
end
