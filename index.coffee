config = require "./config.json"
async = require "async"
crypto = require "crypto"

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
			yarespondidas = data.yapreguntadas.rows.map (e)-> e.preguntaid.toString()
			posiblespreguntas = data.preguntas.rows.filter (e)-> yarespondidas.indexOf(e.preguntaid.toString()) is -1

			#datos de cajon
			retval.leaderboard = data.leaderboard.rows.map (e)-> [e.name,e.photo, e.correct or 0]
			retval.leaderboard.sort (a,b)-> b[2]-a[2]
			retval.leaderboard = retval.leaderboard[0..9]
			retval.status.g = data.leaderboard.rows.filter((e)->return e.userid is request.payload.id).map((e)->( e.correct or 0))[0]

			return reply(retval) if posiblespreguntas.length is 0

			lapregunta = posiblespreguntas[Math.round(Math.random())*(posiblespreguntas.length-1)]
			retval.id = lapregunta.preguntaid.toString()
			retval.q = lapregunta.q
			retval.a = lapregunta.as.map (e)->
				return {id:crypto.createHash('md5').update(e).digest("hex"), text:e}
			return reply(retval)
}

server.route {
	method :"POST",
	path : "/resp",
	handler : (request,reply)->
		return reply(new Error('Invalid Body')) if !request.payload.userid? or !request.payload.id? or !request.payload.r?
		async.parallel {
			pregunta : (cb)->
				cassandra.execute "select \"a\" from concursobooth.preguntas where preguntaid = ?",[request.payload.id],{prepare:true}, cb
			respuesta : (cb)->
				cassandra.execute "select userid,preguntaid from concursobooth.respuestas where preguntaid = ? and userid = ?",[request.payload.id,request.payload.userid],{prepare:true}, cb
			userdata : (cb)->
				cassandra.execute "select ans,correct from concursobooth.usuarios where userid = ?", [request.payload.userid], {prepare:true}, cb
		},(err,data)->
			console.log err if err?
			return reply(err) if err?
			return reply(new Error('Invalid Question')) if !Array.isArray(data.pregunta?.rows) or data.pregunta.rows.length isnt 1 
			return reply(new Error('Invalid User')) if !Array.isArray(data.userdata?.rows) or data.userdata.rows.length isnt 1
			userdata = data.userdata.rows[0]
			retval = {
				correct : crypto.createHash('md5').update(data.pregunta.rows[0].a).digest("hex"),
				answered : request.payload.r
			}
			if data.respuesta.rows?.length is 0
				# consider answer if it is not answered 
				batch = [{
					query:"insert into concursobooth.respuestas (userid,preguntaid) values (?,?)",
					params:[request.payload.userid,request.payload.id]
				},{
					query:"update concursobooth.usuarios set ans = ?, correct = ? where userid = ?",
					params:[
						((userdata.ans or 0)+1),
						(if retval.answered is retval.correct then (userdata.correct or 0)+1 else (userdata.correct or 0)),
						request.payload.userid]
				}
				]
				cassandra.batch batch,{prepare:true},(err2,otro)->
					console.log err2 if err2?
					return reply(err) if err?
					return reply(retval)
			else
				return reply(retval)
}

process.on 'SIGINT', ->
    process.exit()


server.start (err)->
	throw err if err?
	console.log "Server running at: #{server.info.uri}"

module.exports = server