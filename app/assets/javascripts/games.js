+function($) {
  Game = function(options) {
    var self = this;
    var correctCards = 0;

    var init = function() {
      alert("Initializing game");
      // Hide the success message
      $('#successMessage').hide();
      $('#successMessage').css( {
        left: '580px',
        top: '250px',
        width: 0,
        height: 0
      } );

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

    // Initialization Logic!
    init();
  };
}(jQuery);

function playCard(event) {
  // only accept playable cards
  var cardIsPlayable = event.target.getAttribute('data-playable');
  if(!(/true/i).test(cardIsPlayable)) {
    alert("C'mon man, you can't play this card! Try another!");
    return;
  }

  var cardSuit = event.target.getAttribute('data-suit');
  var cardValue = event.target.getAttribute('data-actualvalue');
  $.ajax({url: "<%= games_player_action_path %>", type: "POST", data: {id: <%= params[:id] %>, suit: cardSuit, value: cardValue}});
}

function testDrop(event, ui) {
  // only accept playable cards
  var cardIsPlayable = ui.draggable.context.children[0].dataset.playable;
  if(!(/true/i).test(cardIsPlayable)) {
    alert("C'mon man, you can't play this card! Try another!");
    return;
  }

  ui.draggable.addClass( 'correct' );
  ui.draggable.draggable( 'disable' );
  $(this).droppable( 'disable' );
  ui.draggable.position( { of: $(this), my: 'left top', at: 'left top' } );
  ui.draggable.draggable( 'option', 'revert', false );
  var cardSuit = ui.draggable.context.children[0].dataset.suit;
  var cardValue = ui.draggable.context.children[0].dataset.actualvalue;
  $.ajax({url: "<%= games_player_action_path %>", type: "POST", data: {id: <%= params[:id] %>, suit: cardSuit, value: cardValue}});
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
    $('#successMessage').show();
    $('#successMessage').animate( {
      left: '380px',
      top: '200px',
      width: '400px',
      height: '100px',
      opacity: 1
    } );
  }
}
