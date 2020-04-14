Vidchat = function(){
  var started = false;// this local host
  var ice = null, offer = null, answer = null;
  var enabled = []; // other players

  var startButton = $(document).find('#callButton');
  var hangupButton = document.getElementById('hangupButton');
  hangupButton.disabled = true;

  var current_player = $(".webrtc").data("index"); // Profile, not seat number (aka seat number always 0)
  // TODO: make current_player comparisons
  // between any 2 players - the 'lower index' is the offer index
  // aka: compare current_player vs other_user

  hangupButton.addEventListener('click', function(){ alert("HANGUP TODO"); });

  var webrtc = new RTCPeerConnection({
    iceServers: [
      {
        urls: [
          "stun:stun.stunprotocol.org",
        ]
      }
    ]
  });

  startButton.on("click", function(){
    navigator
      .mediaDevices
      //.getUserMedia({ video: true }) 
      .getUserMedia({ video: true, audio: true})
      .then((localStream) => {
        // display our local video in the respective tag
        const localVideo = document.getElementById("video-0");
        localVideo.srcObject = localStream;
    
        // our local stream can provide different tracks, e.g. audio and
        // video. even though we're just using the video track, we should
        // add all tracks to the webrtc connection
        for (const track of localStream.getTracks()) {
          webrtc.addTrack(track, localStream);
        }
        
        send_message("start_call", null);
        started = true;
        $(document).trigger("poll_for_update"); // override polling process
        startButton.addClass("hidden");
      });
   
  })

  async function send_message(type, message){
    console.log("Send Message: " + type);
    path = location.pathname + "/webrtc"
    $.ajax({
      url: path,
      data: { type: type, message: message },
      method: "POST",
      success: function(){ /*console.log("Submitted message")*/ },
      error: function(){ console.log("Failed to submit") }
    })
  }

  async function handle_message(message, other_user) {
    var data = message.message;
    console.log("Handle Message: Remote #" + other_user + ": " + message.type);

    // TODO: check who sent it - player index
    // TODO: check index of new message received?
    // TODO: dont re-process things from users
    // TODO: offer, answer, ice should be arrays, with 'other_user'

    if(message.type === "start_call"){
      if(current_player !== 0){ return }
      //if(!offer){
        offer = await webrtc.createOffer();
        await webrtc.setLocalDescription(offer);
      //}
      offer_s = JSON.parse(JSON.stringify(offer))
      send_message('webrtc_offer', offer_s);
    } else if(message.type ===  'webrtc_offer'){
      if(current_player === 0){ return }
      // TODO: only non-0
      //if(!answer){
        await webrtc.setRemoteDescription(data);
        answer = await webrtc.createAnswer();
        await webrtc.setLocalDescription(answer);
      //}
      answer_s = JSON.parse(JSON.stringify(answer))
      send_message("webrtc_answer", answer_s)
    } else if(message.type === 'webrtc_answer'){
      if(current_player !== 0){ return }
      // TODO: only host 0
      //if(!enabled[other_user]){
        await webrtc.setRemoteDescription(data);
        enabled[other_user] = true;
      //}
    } else if(message.type === "webrtc_ice_candidate"){
      //if(!ice){
        ice = data
        await webrtc.addIceCandidate(data); 
      //}
    } else {
      console.log(message)
      alert("Unknown message");
    }
  }

  $(document).on("vidchat_message", function(e, data){
    if(!started){return;}
    if(!data) {return}
    if(!data.streams) {return}
    // skip user 0 - local host
    //if(event.data.length <= 1){
    //  return; // no other players yet
    //}
    // LOOP OVER STREAMS

    var other_user = 1
    if(enabled[other_user] === true){return} // stop processing

    // TODO: do we need to process multiple messages?
    var other_user_queue = data.streams[other_user];
    if(!other_user_queue){ return }
    if(other_user_queue.length === 0){ return }
    var message = other_user_queue[other_user_queue.length - 1]
    handle_message(message, other_user)
  });

  webrtc.addEventListener("icecandidate", (event) => {
    if(!event.candidate){
      return;
    }
    // when we discover a candidate, send it to the other
    // party through the signalling server
    send_message(
      "webrtc_ice_candidate",
      JSON.parse(JSON.stringify(event.candidate))
    );
  });

  webrtc.addEventListener("track", (event) => {
    // we received a media stream from the other person. as we're sure 
    // we're sending only video streams, we can safely use the first
    // stream we got. by assigning it to srcObject, it'll be rendered
    // in our video tag, just like a normal video
    const remoteVideo = document.getElementById("video-1");
    remoteVideo.srcObject = event.streams[0];
  });

}
