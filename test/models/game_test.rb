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

  test "suit_order defines a suit order" do
    s3 = Card.new "Spades", 3
    h2 = Card.new "Hearts", 2
    d1 = Card.new "Diamonds", 1
    c0 = Card.new "Clubs", 0
    assert_equal 0, s3.suit_order( s3 )
    assert_equal -1, s3.suit_order( h2 )
    assert_equal 1, d1.suit_order( h2 )
    assert_equal -1, d1.suit_order( c0 )
  end
  
  test "suit_order falls back to value" do
    s0 = Card.new "Spades", 0
    s1 = Card.new "Spades", 1
    s2 = Card.new "Spades", 2
    s3 = Card.new "Spades", 3
    assert_equal 0, s0.suit_order( s0 )
    assert_equal -1, s0.suit_order( s1 )
    assert_equal 1, s2.suit_order( s1 )
    assert_equal -1, s2.suit_order( s3 )
  end
  
  test "can sort using suit_order" do
    s3 = Card.new "Spades", 3
    h2 = Card.new "Hearts", 2
    d1 = Card.new "Diamonds", 1
    c0 = Card.new "Clubs", 0
    
    hand = [ c0, d1, h2, s3 ]
    hand.sort! { |a,b| a.suit_order b }
    
    assert_equal [ s3, h2, d1, c0 ], hand
  end
end
