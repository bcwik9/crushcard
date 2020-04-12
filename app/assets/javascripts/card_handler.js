CardHandler = function(game){
    var correctCards = 0;
    var d = game.data();
    var game_id = d.id,
     played_cards = d.table,
     player_action_path = d.playerPath;

   var hand = game.find("#cardPile"); 

    var init = function(){
      hand.on("click", ".playing_card", card_in_hand_clicked)
     
      game.find(".playing_card").each(function(i, card){
        card = $(card);
        if(card.data('suit')){
          DrawCard.draw_card(card.data('suit'), card.data('value'), card.attr('id'), game);
        }
      });
    
      game.find('#table-card-0').droppable( {
        accept: '#cardPile div',
        hoverClass: 'hovered',
        drop: testDrop
      });
    
      // Create the card slots
      var words = [ 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten' ];
      // TODO: drag and drop not working
      for ( var i=1; i<=10; i++ ) {
        $('<div>' + words[i-1] + '</div>').data( 'number', i ).appendTo( '#cardSlots' ).droppable( {
          accept: '#cardPile .playing_card',
          hoverClass: 'hovered',
          drop: handleCardDrop
        });
      }
    }
    
  var card_in_hand_clicked = function(e){
    if(hand.find(".playing").length > 0){ return; } // already played a card
    var card = $(e.target);

    if(card.hasClass("selected")){
      card.addClass("playing");
      playCard(e);
    } else {
      hand.find(".selected").removeClass("selected");
      card.addClass("selected");
    }
  };
    
    function playCard(event) {
      var card = $(event.target);
      // only accept playable cards
      // Note: use server for validation with more precise messaging
      // instead of js flag here
      /*
      var playable  = card.data("playable");
        if(false && !playable) {
          hand.find(".playing").removeClass("playing")
          // TODO: add reason
          window.show_game_message(
            "You can't play this card right now!" // Not your turn/You have to bid/follow suit."
          );
          return;
        }
        */
        
        var suit = card.data('suit');
        var value = card.data('actualvalue');

        DrawCard.draw_card(suit, card.data('value'), "table-card-0", game);

        $.ajax({
          url: player_action_path + ".json", 
          type: "POST", 
          data: {suit: suit, value: value},
          success: card_played,
          error: failed
        });

    }

    var failed = function(){
      show_failure("Failed to make action. Please refresh page")
    }

    var card_played = function(data){
      if(data['html']){
        window.new_board = data;
        window.load_new_board();
      } else {// expect message
        show_failure(data['message'] || "Unknown error, please refresh page")
      }
    };

    var show_failure = function(message){
      hand.find(".playing").removeClass("playing")
      DrawCard.clear_bottom_card(game);
      window.show_game_message(message)
    }
    
    function testDrop(event, ui) {
      ui.draggable.addClass( 'correct' );
      ui.draggable.draggable( 'disable' );
      $(this).droppable( 'disable' );
      ui.draggable.position( { of: $(this), my: 'left top', at: 'left top' } );
      ui.draggable.draggable( 'option', 'revert', false );
      var cardSuit = ui.draggable.context.children[0].dataset.suit;
      var cardValue = ui.draggable.context.children[0].dataset.actualvalue;
      $.ajax({
        url: player_action_path + ".json", 
        type: "POST", 
        data: {id: game_id, suit: cardSuit, value: cardValue},
        success: card_played,
        error: failed
      });
    }
    
    function handleCardDrop( event, ui ) {
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
       
    }

  init();
}
