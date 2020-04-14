Vidchat = function(){
  var started = false;// this local host
  var enabled = []; // other players

  var startButton = document.getElementById('callButton');
  var hangupButton = document.getElementById('hangupButton');
  hangupButton.disabled = true;

  hangupButton.addEventListener('click', function(){ alert("HANGUP TODO"); });

  var webrtc = new RTCPeerConnection({
    iceServers: [
      {
        urls: [
          "stun:stun.stunprotocol.org",
        ],
      },
    ],
  });

  $(startButton).on("click", function(){
    navigator
      .mediaDevices
      .getUserMedia({ video: true })
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
      });
  })

  async function send_message(type, message){
    path = location.pathname + "/webrtc"
    $.ajax({
      url: path,
      data: { type: type, message: message },
      method: "POST",
      success: function(){ console.log("Submitted message") },
      error: function(){ console.log("Failed to submit") }
    })
  }

  async function handle_message(message, other_user) {
    var data = message.message;

    // TODO: check who sent it - player index
    // TODO: check index of new message received?
    // TODO: dont re-process things from users
    if(message.type === "start_call"){
      console.log("Remote party started call");
      var offer = await webrtc.createOffer();
      await webrtc.setLocalDescription(offer);
      offer = JSON.parse(JSON.stringify(offer))
      send_message('webrtc_offer', offer);
    } else if(message.type ===  'webrtc_offer'){
      console.log("Remote party sent offer");
      await webrtc.setRemoteDescription(data);
      var answer = await webrtc.createAnswer();
      await webrtc.setLocalDescription(answer);
      answer = JSON.parse(JSON.stringify(answer))
      send_message("webrtc_answer", answer)
    } else if(message.type === 'webrtc_answer'){
      console.log("Remote party sent answer");
      await webrtc.setRemoteDescription(data);
      enabled[other_user] = true;
    } else if(message.type === "webrtc_ice_candidate"){
      console.log("Remote party sent ice candidate:", data.candidate);
      //var init = new RTCIceCandidateInit(data)
      //var candidate = new RTCIceCandidate(data)
      await webrtc.addIceCandidate(data); 
      //await webrtc.addIceCandidate(data.candidate);
    } else {
      console.log("UNKNOWN MESSGAGE =====");
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

    //var other_user = 0 // self chat - DOES NOT WORK - rtc config issue
    var other_user_queue = data.streams[other_user];
    console.log("Message Queue", other_user_queue)
    if(!other_user_queue){ return }
    if(other_user_queue.length === 0){ return }
    var message = other_user_queue[other_user_queue.length - 1]
    console.log("Handle message: " + message.type, message.message)
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
