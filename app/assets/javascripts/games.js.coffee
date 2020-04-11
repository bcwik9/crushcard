window.new_board = null
window.load_new_board = ()->
  console.log("LOAD NEW BOARD");
  console.log(window.new_board);
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
 
    game.find(".start_game").on('click', @start_game_clicked)
    game.find(".bid_form a").on('click', @bid_clicked)
    $(document).find(".join_game button").on('click', @add_player_clicked)

  bid_clicked: (e) =>
    e.preventDefault();
    path = $(e.target).data('url')
    bid = game.find(".bid_form #bid").val()
    console.log("Bid Clicked: " + bid);
    $.post(
      path,
      {bid: bid},
      success: @success,
      error: @failed
    )
    return false;

  start_game_clicked: (e)=>
    e.preventDefault();
    path = $(e.target).data('url')
    $.post(
      path,
      {},
      success: @success,
      error: @failed
    )
    return false;

  add_player_clicked: (e)=>
    jg = $(document).find(".join_game")
    username = jg.find("#username").val()
    if username && username.length >= 1
      jg.addClass("hidden")
      path = jg.data("url")
      $.post(
        path,
        { username: username },
        success: @success,
        error: @failed
      )
    else
      window.show_game_message("Must set a name for yourself") 

  get_updated_board: =>
    # TODO: pass in last_updated_at, only get response if new state
    $.ajax({
      url: config.url + ".json?updated=" + config.updated, 
      method: "GET", 
      success: @success,
      error: @failed
    })

  wait_and_poll: =>
    # TODO: faster once game strarted
    # Note: poll time should get faster
    # poll should hard-refresh after 10 seconds
    setTimeout @get_updated_board, 1000

  success: (data)=>
    console.log("SUCCESS FROM SERVER")
    if data && data['html']
      console.log("Loading HTML")
      window.new_board = data
      window.load_new_board();
    else if data && data['message']
      console.log("Loading message")
      window.show_game_message(data['message'])
    else
      @wait_and_poll()

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