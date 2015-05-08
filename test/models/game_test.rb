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

  test "display_name works for face cards" do
    assert_equal "J", Card.new( "Spades", 9 ).display_name
    assert_equal "Q", Card.new( "Spades", 10 ).display_name
    assert_equal "K", Card.new( "Spades", 11 ).display_name
    assert_equal "A", Card.new( "Spades", 12 ).display_name
  end
end
