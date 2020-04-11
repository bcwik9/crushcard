CardHandler = function(game){
    var correctCards = 0;
    var d = game.data();
    var game_id = d.id,
     played_cards = d.table,
     dealt_cards = d.dealt, // in this persons hand only
     player_action_path = d.playerPath;

   var hand = game.find("#cardPile"); 

    var init = function(){
      hand.on("click", ".playing_card", card_in_hand_clicked)
      $.each(dealt_cards, function(i, card){
        var canvas = game.find("#canv"+i);
        // TODO: use canvas.data()... or vice versa
        // loop over rendered cards - no need for 'dealt-cards' at all
        DrawCard.draw_card(card[0], card[1], "canv"+i, game);
      });
    
      game.find('#bottom').droppable( {
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

      $.each(played_cards, function(i, card){
        DrawCard.draw_card(card[0], card[1], card[2], game);
      });
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
      var playable  = card.data("playable");
        if(!playable) {
          hand.find(".playing").removeClass("playing")
          // TODO: add reason
          window.show_game_message(
            "You can't play this card right now!" // Not your turn/You have to bid/follow suit."
          );
          return;
        }
    
        var cardSuit = card.data('suit');
        var cardValue = card.data('actualvalue');
        $.ajax({
          url: player_action_path + ".json", 
          type: "POST", 
          data: {id: game_id, suit: cardSuit, value: cardValue},
          success: function(data){
            console.log("Card Played!");
            console.log(data);
            window.new_board = data;
            setTimeout(window.load_new_board, 2500);
          }
        });

    }
    
    function testDrop(event, ui) {
        var cardIsPlayable = $(ui.draggable.context.children[0]).data("playable");
        if(!cardIsPlayable) {
          window.show_game_message(
              "You can't play this card right now!"
              );
          return;
        }
    
        ui.draggable.addClass( 'correct' );
        ui.draggable.draggable( 'disable' );
        $(this).droppable( 'disable' );
        ui.draggable.position( { of: $(this), my: 'left top', at: 'left top' } );
        ui.draggable.draggable( 'option', 'revert', false );
        var cardSuit = ui.draggable.context.children[0].dataset.suit;
        var cardValue = ui.draggable.context.children[0].dataset.actualvalue;
        $.ajax({url: player_action_path, type: "POST", data: {id: game_id, suit: cardSuit, value: cardValue}});
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
       
      // If all the cards have been placed correctly then display a message
      // and reset the cards for another go
     
      if ( correctCards == 10 ) {
        $('#successMessage').removeClass("hidden");
        $('#successMessage').animate({
          left: '380px',
          top: '200px',
          width: '400px',
          height: '100px',
          opacity: 1
        });
      }
     
    }

  init();
}
