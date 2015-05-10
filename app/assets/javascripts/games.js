+function($) {
  Game = function(options) {
    var self = this;
    var correctCards = 0;

    var init = function() {
      $('#cardSlots').html( '' );

      $('#bottom').droppable( {
        accept: '#cardPile div',
        hoverClass: 'hovered',
        drop: testDrop
      } );

      // TODO: Needed? self.create_suffled_cards_pile();

      var words = [ 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten' ];
      for ( var i=1; i<=10; i++ ) {
        $('<div>' + words[i-1] + '</div>').data( 'number', i ).appendTo( '#cardSlots' ).droppable( {
          accept: '#cardPile div',
          hoverClass: 'hovered',
          drop: handleCardDrop
        } );
      }

      initial_card_logic();
    };

    var create_suffled_cards_pile = function(){
      // Create the pile of shuffled cards
      var numbers = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
      numbers.sort( function() { return Math.random() - .5 } );

      for ( var i=0; i< 52; i++ ) {
        $("#card"+i).click(function(event) {
          if($(this).hasClass("selected")) {
            playCard(event);
          }
          $(this).addClass("selected");
          $(this).siblings().removeClass("selected");
          $(this).css({"background":"blue"});
          $(this).siblings().css({"background":"white"});
        });
        var currentCanvas = document.getElementById("canv"+i);
        draw_card(currentCanvas.dataset.suit, currentCanvas.dataset.value, "canv"+i);
      }
    };

    var gameId = function(){
      $("#game_data").data('id');
    };

    var playerActionPath = function(){
      // TODO: make this /games/:id/palyer_action
      "/games/player_action"
    };

    var sendCard = function(cardSuit, cardValue){
      $.ajax({url: playerActionPath, type: "POST", data: {id: gameId, suit: cardSuit, value: cardValue}});
    };

    var playCard = function(event) {
      // only accept playable cards
      var cardIsPlayable = event.target.data('playable');
      if(!(/true/i).test(cardIsPlayable)) {
        alert("C'mon man, you can't play this card! Try another!");
        return;
      }

      var cardSuit = event.target.data('suit');
      var cardValue = event.target.data('actualvalue');
      sendCard(cardSuit, cardValue);
    };

    var testDrop = function(event, ui) {
      // only accept playable cards
      var cardIsPlayable = ui.draggable.context.children[0].data('playable');
      if(!(/true/i).test(cardIsPlayable)) {
        alert("C'mon man, you can't play this card! Try another!");
        return;
      }

      ui.draggable.addClass( 'correct' );
      ui.draggable.draggable( 'disable' );
      $(this).droppable( 'disable' );
      ui.draggable.position( { of: $(this), my: 'left top', at: 'left top' } );
      ui.draggable.draggable( 'option', 'revert', false );
      var cardSuit = ui.draggable.context.children[0].data('suit');
      var cardValue = ui.draggable.context.children[0].data('actualvalue');
      sendCard(cardSuit, cardValue);
    };

    var handleCardDrop = function ( event, ui ) {
      var slotNumber = $(this).data( 'number' );
      var cardNumber = ui.draggable.data( 'number' );

      // If the card was dropped to the correct slot,
      // change the card colour, position it directly
      // on top of the slot, and prevent it being dragged
      // again

      if ( slotNumber == cardNumber ) {
        ui.draggable.addClass( 'correct' );
        ui.draggable.draggable( 'disable' );
        $(this).droppable( 'disable' );
        ui.draggable.position( { of: $(this), my: 'left top', at: 'left top' } );
        ui.draggable.draggable( 'option', 'revert', false );
        correctCards++;
      } 

      // If all the cards have been placed correctly then display a message
      // and reset the cards for another go
      if ( correctCards == 10 ) {
        alert("Game is Over");
      }
    };

    var draw_card = function(suit, value, canvas){
      var canvas = document.getElementById(canvas);
      var context = canvas.getContext("2d");
      var suit_width = canvas.width * 0.285;
      var suit_height = canvas.height * 0.257;

      context.font = "20pt c";
      context.fillText(value, canvas.width/2-8, canvas.height/2+5);

      if((/spade/i).test(suit)){
        drawSpade(context, (suit_width/2+5), 0, suit_width, suit_height);
        drawSpade(context, canvas.width-((suit_width/2+5)), canvas.height-suit_height, suit_width, suit_height);
      }
      if((/diamond/i).test(suit)){
        drawDiamond(context, (suit_width/2+5), 0, suit_width, suit_height);
        drawDiamond(context, canvas.width-((suit_width/2+5)), canvas.height-suit_height, suit_width, suit_height);
      }
      if((/club/i).test(suit)){
        drawClub(context, (suit_width/2+5), 0, suit_width, suit_height);
        drawClub(context, canvas.width-((suit_width/2+5)), canvas.height-suit_height, suit_width, suit_height);
      }
      if((/heart/i).test(suit)){
        drawHeart(context, (suit_width/2+5), 0, suit_width, suit_height);
        drawHeart(context, canvas.width-((suit_width/2+5)), canvas.height-suit_height, suit_width, suit_height);
      }
    };

    var initial_card_logic = function(){
      var trump_suit = $('#game_data').data('trumpSuit');
      var trump_name = $('#game_data').data('trumpName');
      draw_card(trump_suit, trump_name, "trump");
      var played_cards = $('#game_data').data('playedCards');
      var sides = ["bottom", "left", "top", "right","unknown-fifth-player"]; //TODO: 5 player logic
      for ( var i=0; i<played_cards; i++ ) {
        var card_suit = $('#game_data').data('playedCard'+i+'Suit');
        var card_name = $('#game_data').data('playedCard'+i+'Name');
        draw_card(card_suit, card_name, sides[i]);
      }
    };

    // Initialization Logic!
    init();
  };
}(jQuery);

