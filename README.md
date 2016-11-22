# BoothAPI
This is a backend for a multiple answer contest; users can sign in using facebook; the backend is intended to be Cassandra and a config.json file is needed in the root of the poroject; CI can be done using GitLab.

### config.json
```
{
	"cassandra" : {
        "maxPrepared" : 5000,
	    "contactPoints": ["10.0.0.1","10.0.0.1"],
	    "username" : "user",
	    "password" : "password",
	     "queryOptions" : {
		"consistency" : 6
	    }
	},
	"hapi" : { 
	    "host": "0.0.0.0", 
	    "port": 8081,
	    "routes" : {
	    	"cors" : true
	    }
	}
}
```

### database structure

```
CREATE KEYSPACE concursobooth WITH replication = {'class': 'NetworkTopologyStrategy', 'WHATEVERCHANGEME': '3'};

CREATE TABLE concursobooth.preguntas (
    preguntaid uuid PRIMARY KEY,
    a text,
    as set<text>,
    q text
);

CREATE TABLE concursobooth.respuestas (
    userid text,
    preguntaid uuid,
    PRIMARY KEY (userid, preguntaid)
);

CREATE TABLE concursobooth.usuarios (
    userid text PRIMARY KEY,
    ans int,
    correct int,
    name text,
    payload text,
    photo text
) ;
```