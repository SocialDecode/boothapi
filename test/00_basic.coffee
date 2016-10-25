Code = require "code"
lab = exports.lab = require("lab").script()
server = require "../index.coffee"
config = require "../config.json"
cassandralib = require 'cassandra-driver'
userdata = require "../payload.json"
crypto = require "crypto"
cassandra = {}
question = {}
answer_bad = ""
answer_good = ""

lab.experiment "Basic HTTP Tests", ->
	lab.test "Database Setup", (done)->
		config.cassandra.authProvider =  new cassandralib.auth.PlainTextAuthProvider(config.cassandra.username,config.cassandra.password)
		cassandra = new cassandralib.Client(config.cassandra)
		cassandra.execute "select * from concursobooth.preguntas limit 1", (err,data)->
			Code.expect(err).to.be.null()
			Code.expect(data).to.be.an.object()
			Code.expect(data.rows).to.be.an.array()
			question = data.rows[0]
			answer_bad = crypto.createHash('md5').update((question.as.filter((e) -> return e isnt question.a))[0]).digest("hex")
			answer_good = crypto.createHash('md5').update((question.as.filter((e) -> return e is question.a))[0]).digest("hex")
			cassandra.execute "delete from concursobooth.respuestas where userid = ? and preguntaid = ?", [userdata.id, question.preguntaid], (err2,data2)->
				Code.expect(err2).to.be.null()
				cassandra.execute "update concursobooth.usuarios set ans=0,correct=0 where userid = ?", [userdata.id], (err3,data2)->
					Code.expect(err3).to.be.null()
					done()
	lab.test "GET / (no endpoint test)", (done)->
		server.inject {method: "GET",url: "/"}, (response)->
			Code.expect(response.statusCode).to.equal(404)
			done()
	lab.test "Get Quetion", (done)->
		server.inject {method: "POST",url: "/ask", payload:userdata}, (response)->
			Code.expect(response.statusCode).to.equal(200)
			Code.expect(response.result,"Payload").to.be.an.object()
			Code.expect(response.result.status, "Status").to.be.an.object()
			Code.expect(response.result.leaderboard, "Leaderboard").to.be.an.array()
			Code.expect(response.result.q, "Question text").to.be.an.string()
			Code.expect(response.result.id, "Question id").to.be.an.string()
			Code.expect(response.result.a, "Answer").to.be.an.array()
			Code.expect(response.result.a[0].id, "Answer 1 id").to.be.an.string()
			Code.expect(response.result.a[0].text, "Answer 1 text").to.be.an.string()
			done()
	lab.test "Wrong Answer", (done)->
		server.inject {method:"POST",url:"/resp", payload:{userid:userdata.id,id:question.preguntaid.toString(),r:answer_bad}}, (response)->
			Code.expect(response.statusCode).to.equal(200)
			Code.expect(response.result,"Payload").to.be.an.object()
			Code.expect(response.result.correct is response.result.answered).to.be.false()
			cassandra.execute "select ans, correct from concursobooth.usuarios where userid = ?", [userdata.id], (err4,data4)->
				Code.expect(err4).to.be.null()
				Code.expect(data4.rows).to.be.an.array()
				Code.expect(data4.rows[0]).to.be.an.object()
				Code.expect(data4.rows[0].ans).to.equal(1)
				Code.expect(data4.rows[0].correct).to.equal(0)
				done()
	lab.test "Right Answer", (done)->
		cassandra.execute "delete from concursobooth.respuestas where userid = ? and preguntaid = ?", [userdata.id, question.preguntaid], (err5,data2)->
			Code.expect(err5).to.be.null()
			server.inject {method:"POST",url:"/resp", payload:{userid:userdata.id,id:question.preguntaid.toString(),r:answer_good}}, (response)->
				Code.expect(response.statusCode).to.equal(200)
				Code.expect(response.result,"Payload").to.be.an.object()
				Code.expect(response.result.correct is response.result.answered).to.be.true()
				cassandra.execute "select ans, correct from concursobooth.usuarios where userid = ?", [userdata.id], (err6,data4)->
					Code.expect(err6).to.be.null()
					Code.expect(data4.rows).to.be.an.array()
					Code.expect(data4.rows[0]).to.be.an.object()
					Code.expect(data4.rows[0].ans).to.equal(2)
					Code.expect(data4.rows[0].correct).to.equal(1)
					done()


