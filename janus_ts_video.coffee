#!/usr/bin/env coffee

child_process = require 'child_process'
Janus = require 'janus-gateway-js'
yargs = require 'yargs'

start_streaming = (host, port) ->
	pipeline = """
	filesrc location=/dev/stdin !
	tsdemux ! h264parse name=demux
	demux. ! rtph264pay config-interval=-1 !
	udpsink host=#{host} port=#{port}
	"""
	pipeline = pipeline.split(/\s+/)
	
	gst = child_process.spawn "gst-launch-1.0", pipeline,
		stdio: 'inherit'

	return new Promise (a, r) -> gst.once 'close', a

stream_to_janus = (opts={}) ->
	janus = opts.janus
	session = new Janus.Client "http://localhost:8188"
	connection = await session.createConnection "idontknowwhatthisis"
	session = await connection.createSession()
	streams = await session.attachPlugin Janus.StreamingPlugin.NAME

	# Janus doesn't allow for requesting a random
	# port, so we'll try a few
	for porttry in [0...100]
		try
			_videoport = 15000 + porttry*4
			result = await streams.create 0,
				type: "rtp"
				description: opts.name ? "#{_videoport}"
				audio: false
				video: true
				videoport: _videoport
				videopt: 100
				videortpmap: "H264/90000"
				admin_key: "supersecret"
			videoport = _videoport
			break
		catch error
			if error.code != 456
				throw error
	if not result?
		throw error
	stream = result.getPluginData 'stream'
	
	cleanup = ->
		if cleanup.done
			return
		cleanup.done = true
		await streams.destroy stream.id, {}
		await session.destroy()
		await connection.close()
	
	console.info "Streaming to port #{videoport} with id #{stream.id}"

	try
		code = await start_streaming '127.0.0.1', videoport
	finally
		cleanup()


if module == require.main then do ->
	opts = yargs
		.option 'name', alias: 'n', describe: 'Stream name'
		.help()
		.argv
	await stream_to_janus opts
