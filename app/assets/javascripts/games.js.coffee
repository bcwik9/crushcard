window.new_board = null
window.load_new_board = ()->
  console.log("LOAD NEW BOARD");
  board = $(window.new_board['html']); # TODO: if html present
  new Games(board)
  $('#game-wrapper').html(board)

window.show_game_message = (message)->
  msg = $('#game-wrapper #message')
  msg.find(".text").html(message)
  msg.removeClass("hidden")
  msg.find("a").focus()
  msg.one "click", "a", (e)->
    e.preventDefault();
    $('#game-wrapper #message').addClass("hidden");
    return false


class Games
  game = null
  config = null

  constructor: (game_element)->
    console.log("Games New ------")
    game = game_element
    config = game.data();

    new CardHandler(game); # draw cards and setup action listeners

    if config.poll == true
      console.log("Poll for updates from other users");
      @wait_and_poll()
    else 
      console.log("Dont Poll - waiting for current user action");
 
  get_updated_board: =>
    # TODO: pass in last_updated_at, only get response if new state
    $.ajax({
      url: config.url + ".json", 
      method: "GET", 
      success: @success,
      error: @failed
    })

  wait_and_poll: =>
    # TODO: faster once game strarted
    setTimeout @get_updated_board, 3000

  success: (data)=>
    window.new_board = data
    window.load_new_board();

  failed: -> 
    window.show_game_message "Failed to update game, please refresh page."

jQuery ->
  console.log("Games.js starting");
  new Games($("#game"))

  $('#successMessage').css({
    left: '580px',
    top: '250px',
    width: 0,
    height: 0
  });
  # TODO: if game_list present
  $('#game_list').DataTable({
    "order": [[0, "desc"]],
    "columnDefs":[{ "targets":[0], "visible": false, "searchable": false}]
  });