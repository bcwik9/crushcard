require 'test_helper'

class GameTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "deck has 52 cards" do
    d = Card.get_deck
    assert_equal 52, d.size, 'unexpected number of cards in deck!'
  end

  test "card cannot have invalid suit" do
    assert_raises(RuntimeError) {
      Card.new "Blah", 4
    }
  end
end
