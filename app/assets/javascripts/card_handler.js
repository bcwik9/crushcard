CardHandler = function(game){
    var correctCards = 0;

    var d = game.data();
    var game_id = d.id;
    var played_cards = d.table; 
    var dealt_cards = d.dealt;
    var player_action_path = d.playerPath;

    var init = function(){
      // Reset the game
      correctCards = 0;
     
      // Create the pile of shuffled cards
      var numbers = [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ];
      numbers.sort( function() { return Math.random() - .5 } );

      game.on("click", "#cardPile .playing_card", function(e){
        var card = $(e.target);
        if(card.hasClass("selected")){
          playCard(e);
        } else {
          card.parents("#cardPile").find(".selected").removeClass("selected");
          card.addClass("selected");
        }
      });

      console.log(dealt_cards);
      $.each(dealt_cards, function(i, card){
        var canvas = game.find("#canv"+i);
        console.log(canvas.data()); // TODO: use card.data()... or vice versa
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
    
    function playCard(event) {
      var card = $(event.target);
      // only accept playable cards
      var playable  = card.data("playable");
        if(!playable) {
          // TODO: show notification
          alert("You can't play this card right now! You have to follow suit.");
          // TODO: add reason - waiting for - or - follow suit
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
        // only accept playable cards
        var cardIsPlayable = ui.draggable.context.children[0].dataset.playable;
        if(!(/true/i).test(cardIsPlayable)) {
          alert("You can't play this card right now!");
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
