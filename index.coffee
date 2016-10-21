config = require "./config.json"
async = require "async"

#hapi
server = new (require("hapi")).Server()
server.connection(config.hapi)

#database
cassandralib = require 'cassandra-driver'
config.cassandra.authProvider =  new cassandralib.auth.PlainTextAuthProvider(config.cassandra.username,config.cassandra.password)
cassandra = new cassandralib.Client(config.cassandra)



server.route {
		method: 'POST',
		path:'/ask', 
		"handler": (request, reply) ->
			return reply(new Error('Invalid Body')) if !request.payload?.id?
			retval = {status:{}}
			async.parallel {
				guardaplayer: (cb)->
					updatepayload = {userid:request.payload.id,payload:JSON.stringify(request.payload)}
					updatepayload.photo = request.payload.picture.data.url if request.payload.picture?.data?.url?
					updatepayload.name = request.payload.name if request.payload.name?
					vals = Object.keys(updatepayload).map (e)-> updatepayload[e]
					cassandra.execute "insert into concursobooth.usuarios (#{Object.keys(updatepayload).join(',')}) values(#{vals.map((e)->'?').join(',')})",vals,{prepare:true}, cb
				leaderboard: (cb)->
					cassandra.execute "select userid,name,photo,ans,correct from concursobooth.usuarios ", [], cb
				preguntas : (cb)->
					cassandra.execute "select preguntaid, q, \"as\" from concursobooth.preguntas", cb
				yapreguntadas:(cb)->
					cassandra.execute "select preguntaid from concursobooth.respuestas where userid = ?", [request.payload.id],{prepare:true},cb
			},(err,data)->
				console.log err if err?
				return reply(err) if err?
				yarespondidas = data.yapreguntadas.rows.map (e)-> e.preguntaid
				posiblespreguntas = data.preguntas.rows.filter (e)-> yarespondidas.indexOf(e.preguntaid) is -1
				lapregunta = posiblespreguntas[Math.round(Math.random())*(posiblespreguntas.length-1)]
				retval.id = lapregunta.preguntaid.toString()
				retval.q = lapregunta.q
				retval.a = lapregunta.as.map (e)->
					return {id:new Buffer(e).toString('base64'), text:e}
				retval.leaderboard = data.leaderboard.rows.map (e)-> [e.name,e.photo,Math.round(e.correct/e.ans,2) or 0]
				retval.leaderboard.sort (a,b)-> b[2]-a[2]
				retval.leaderboard = retval.leaderboard[0..9]
				retval.status.g = data.leaderboard.rows.filter((e)->return e.userid is request.payload.id).map((e)->(Math.round(e.correct/e.ans,2) or 0))[0]
				console.log retval
				return reply(retval)
}

server.route {
	method :"POST",
	path : "/resp",
	handler : (request,reply)->
		return {
			correct : "tres",
			answered : request.body.r
		}
}

process.on 'SIGINT', ->
    process.exit()


server.start (err)->
	throw err if err?
	console.log "Server running at: #{server.info.uri}"

