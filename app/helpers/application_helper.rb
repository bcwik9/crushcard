module ApplicationHelper
  def card_suit(card)
    card % 4
  end

  def card_value(card)
    card % 13
  end
end
