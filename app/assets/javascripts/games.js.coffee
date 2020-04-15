window.new_board = null
window.load_new_board = ()->
  window.game.stop();
  board = $(window.new_board['html']); # TODO: if html present
  window.game = new Games(board)
  $('#game-wrapper').html(board)
  if window.new_board['video'] && window.new_board.video.length > 0
    $(document).trigger("vidchat_message", { streams: window.new_board.video })
    

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
  stopped = null
  game = null
  config = null

  constructor: (game_element)->
    stopped = false
    game = game_element
    config = game.data();

    new CardHandler(game); # draw cards and setup action listeners

    if config.poll == true
      @wait_and_poll()
 
    game.find(".start_game").on('click', @start_game_clicked)
    game.find(".start_game").focus()

    game.find(".bid_form a").on('click', @bid_clicked)
    game.find(".bid_form input").focus()

    game.find("a.clear_hand").on('click', @deal_clicked)
    game.find("a.clear_hand").focus()

    $(document).find(".join_game button").on('click', @add_player_clicked)

    game.find(".morph").on('click', @morph_clicked)

    if !config.poll 
      $(document).on("poll_for_update", @get_updated_board)

    if game.data("chime")
      @chime()

  stop: =>
    stopped = true

  chime: =>
    sound = $(document).find(".youre_up_bell").data("src");
    console.log("YOUR UP CHIME: " + sound);
    audio = new Audio(sound);
    audio.volume = 0.05;
    audio.play();

  morph_clicked: (e) =>
    e.preventDefault();
    index = $(document).find(".morph_form #index").val();
    $.ajax(
      $(e.target).data('url'),
      data: { index: index },
      method: "POST",
      success: @success,
      error: @failed
    )
    return false

  deal_clicked: (e) =>
    e.preventDefault();
    path = $(e.target).data('url')
    $.ajax(
      path,
      method: "POST",
      success: @success,
      error: @failed
    )
    return false

  bid_clicked: (e) =>
    e.preventDefault();
    bid = game.find(".bid_form #bid").val()
    $.ajax(
      config.playerPath,
      data: {bid: bid},
      method: "POST",
      success: @success,
      error: @failed
    )
    return false;

  start_game_clicked: (e)=>
    e.preventDefault();
    path = $(e.target).data('url') # TODO: player_path { start: true }
    $.ajax(
      path,
      method: "POST",
      success: @success,
      error: @failed
    )
    return false;

  add_player_clicked: (e)=>
    jg = $(document).find(".join_game")
    username = jg.find("#username").val()
    if username && username.length >= 0
      jg.addClass("hidden")
      path = jg.data("url")
      $.ajax(
        path,
        data: { username: username },
        method: "POST",
        success: @success,
        error: @failed
      )
    else
      window.show_game_message("Must set a name for yourself") 

  get_updated_board: =>
    if stopped
      return

    $.ajax({
      url: config.url + "&updated=" + config.updated, 
      method: "GET", 
      success: @success,
      error: @failed
    })

  wait_and_poll: =>
    # TODO: poll should hard-refresh after 15 seconds/tries
    setTimeout @get_updated_board, 2000

  success: (data)=>
    if data && data['html']
      window.new_board = data
      window.load_new_board();
    else if data && data['message']
      window.show_game_message(data['message'])
    else
      @wait_and_poll()

  failed: -> 
    window.show_game_message "Failed to update game, please refresh page."


jQuery ->
  game = $("#game")
  if game.length > 0
    g = new Games($("#game"))
    window.game = g;
    new Vidchat()

  $('#game_list').DataTable({
    "order": [[0, "desc"]],
    "columnDefs":[{ "targets":[0], "visible": false, "searchable": false}]
  });
