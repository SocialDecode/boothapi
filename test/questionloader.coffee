config = require "../config.json"
async = require "async"
cassandralib = require 'cassandra-driver'
config.cassandra.authProvider =  new cassandralib.auth.PlainTextAuthProvider(config.cassandra.username,config.cassandra.password)
cassandra = new cassandralib.Client(config.cassandra)

Converter = require("csvtojson").Converter
converter = new Converter({})
converter.on "end_parsed",  (jsonArray)->
	cassandra.execute "select * from concursobooth.preguntas", [], (err,data)->
  		throw err if err?
  		console.log jsonArray.length
  		jsonArray = jsonArray.filter (e)->
  			return (data.rows.filter((f)->return e["Pregunta"] is f.q).length is 0)
  		console.log jsonArray.length
		async.eachOfLimit jsonArray, 10, (row,key,cb)->
	  		respuestas = Array(row["Respuesta A"],row["Respuesta B"], row["Respuesta C"], row["Respuesta D"])
	  		respuestas = respuestas.filter (e)->
	  			return e isnt null and e isnt ""
	  		if respuestas.indexOf(row["Respuesta Correcta"]) is -1
	  			console.log "No hay respuesta correcta para la pregunta", row
	  			cb()
	  		else
	  			cassandra.execute "insert into concursobooth.preguntas (preguntaid, a, \"as\", q) values (now(),?,?,?)", [row["Respuesta Correcta"],respuestas,row["Pregunta"]], {prepare:true},(err2,data)->
	  				throw err2 if err2?
	  				cb()
  	,(err)->
  		console.log "done"
  		process.exit 0
  		# if row["Respuesta Correcta"]
  		# cassandra.execute "select * from concursobooth.preguntas limit 1", (err,data)->


require("fs").createReadStream("#{__dirname}/preguntas.csv").pipe(converter)



process.on 'SIGINT', ->
    process.exit()