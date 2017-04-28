Janus = require 'janus-gateway-js'
Adapter = require 'webrtc-adapter'
class NotFound extends Error

stream_from_janus = (element, janus_url, streamname) ->
	session = new Janus.Client janus_url
	connection = await session.createConnection "idontknowwhatthisis"
	session = await connection.createSession()
	streams = await session.attachPlugin Janus.StreamingPlugin.NAME
	response = await streams.list()
	sl = response.getPluginData().list
	mystream = sl.filter((s) -> s.description == streamname)
	if mystream.length < 1
		throw new NotFound("No stream with name #{mystream}")
	mystream = mystream[0]
	streams.on "pc:track:remote", (event) ->
		Adapter.attachMediaStream element, event.streams[0]
	await streams.connect(mystream.id)
	await streams.start()

module.exports = stream_from_janus
module.exports.NotFound = NotFound
