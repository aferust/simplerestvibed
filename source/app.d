module app;

import std.stdio;
import std.json;
import std.typecons: scoped;

import vibe.d;
import dauth;
import hibernated.core;
import hibernated.core: Sessionh = Session;
import ddbc.drivers.sqliteddbc;
import itsdangerous;

alias Serializer = TimedJSONWebSignatureSerializer!(SHA512, Signer!(SHA1, SHA512)); // itsdangerous

enum SECRET_KEY = "Fast code, fast.";


__gshared Sessionh sess;

__gshared User sessionUser;

/+ CORS stuff +/
void sendOptions(HTTPServerRequest req, HTTPServerResponse res)
{
    res.headers["Access-Control-Allow-Origin"] = "*";
    res.writeBody("");
}
void handleCORS(HTTPServerRequest req, HTTPServerResponse res)
{
    res.headers["Access-Control-Allow-Origin"] = "*";
    res.headers["Access-Control-Allow-Headers"] = "Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With";
    res.headers["Access-Control-Allow-Credentials"] = "true";
}
/+ CORS stuff END+/

// shared static this(){ // hibernated does not like module constructor with vibedmain
// we will use a regular main instead.
void main(){
    initDB();
    
    auto router = new URLRouter;

    router.any("*", &handleCORS); // CORS stuff
    router.match(HTTPMethod.OPTIONS, "*", &sendOptions); // CORS stuff
    
    router.post("/newuser", &newUser);
    
    router.any("/loggedin/*", &auth); // loggedin routes will require a user to be authorized

    router.post("/loggedin/gettoken", &getAuthToken); // use this for logging in
    router.post("/loggedin/getuserdata", &getUserData);  // get user data
    router.post("/loggedin/setuserdata", &setUserData);  // set user data

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["::", "127.0.0.1"];

    listenHTTP(settings, router);

    runEventLoop();
}

void auth(HTTPServerRequest req, HTTPServerResponse res){
    import std.functional;
    string uname = performBasicAuth(req, res, "realm", toDelegate(&verifyPassword));
}

shared static ~this(){
    sess.close();
}

@Entity
@Table("User")
class User {
    long id;
    string username;
    string passwordHash;
    string someUserData;

    this(string username, string someUserData = ""){
        this.username = username;
        this.someUserData = someUserData;
    }

    void hashPassword(string password){
        passwordHash = makeHash(toPassword(password.dup)).toString();
    }

    bool verifyPassword(string password){
	    return isSameHash(toPassword(password.dup), parseHash(passwordHash));
    }

    string generateAuthToken(int expiration = 600){
        // we use scoped!T to avoid GC heap allocation // new Serializer(..) can be used though
        auto s = scoped!Serializer(SECRET_KEY, expiration); 
        JSONValue ob = ["id": this.id];
        return s.dumps(ob);
    }

    static User verifyAuthToken(string token){
        auto s = scoped!Serializer(SECRET_KEY);
        JSONValue data;
        try{
            data = s.loads(token);
        } catch (SignatureExpired exp){
            return null;
        } catch (BadSignature exp){
            return null;
        }
        User user = sess.createQuery("FROM User WHERE id=:id").
                                   setParameter("id", data["id"]).uniqueResult!User();
        return user;
    }
}

bool verifyPassword(string username_or_token, string password){
    // first try to authenticate by token
    // writeln(username_or_token, " ", password );
    auto user = User.verifyAuthToken(username_or_token);
    if(user is null){
        // try to authenticate with username/password
        user = sess.createQuery("FROM User WHERE username=:username").
                                   setParameter("username", username_or_token).uniqueResult!User();
        if (user is null || !user.verifyPassword(password))
            return false;
    }
    sessionUser = user;
    return true;
}

/+ request new user:
curl --header "Content-Type: application/json" --request POST --data '{"username":"ferhat","password":"1234"}' "http://localhost:8080/newuser"
+/

/+ request login
curl -u ferhat:1234 -i -X GET "http://localhost:8080/loggedin/gettoken"
+/

/+ request data with token:
curl -u eyJhbGciOiJIUzUxMiIsImV4cCI6MTU3OTUyOTE3MywiaWF0IjoxNTc5NTI4NTczfQ.eyJpZCI6MX0.05CpHeohmXqOgQetwnVXfMc7ZZRcU1S3w-Ql1NLVD7_bgbPZVPVR_J6cWgj_REH4hbToKyAyLv4q9Xr8-sMuWg:unused -i -X GET "http://localhost:8080/loggedin/gettoken"
+/

void newUser(HTTPServerRequest req, HTTPServerResponse res){
    string username = req.json["username"].to!string;
    string password = req.json["password"].to!string;

    if (username is null || password is null)
        res.writeVoidBody(); // 400 missing arguments

    User user = sess.createQuery("FROM User WHERE username=:username").
        setParameter("username", username).uniqueResult!User();
    if(user !is null){
        res.writeJsonBody(["error": "existing user"]);
    }else{
        user = new User(username);
        user.hashPassword(password);
        
        sess.save(user);
        res.writeJsonBody(user);
    }

}

// each response will include a new timed token
// the frontend is responsible for updating the new token in localstorage or cookie-session
JSONValue responseWithNewToken(){
    string token = sessionUser.generateAuthToken(600);
    auto response = JSONValue(["token": token]);
    response["duration"] = 600;
    response["user"] = sessionUser.username;

    return response;
}

void getAuthToken(HTTPServerRequest req, HTTPServerResponse res){
    auto response = responseWithNewToken();

    res.writeJsonBody(response);
}

void getUserData(HTTPServerRequest req, HTTPServerResponse res){
    auto response = responseWithNewToken();

    response["userdata"] = sessionUser.someUserData;

    res.writeJsonBody(response);
}

void setUserData(HTTPServerRequest req, HTTPServerResponse res){
    auto response = responseWithNewToken();
    
    string userdata = req.json["userdata"].to!string; // get userdata from frontend

    sessionUser.someUserData = userdata;
    sess.update(sessionUser); // update database with new data

    res.writeJsonBody(response);
}

void initDB(){
    EntityMetaData schema = new SchemaInfoImpl!(User)();
    SQLITEDriver driver = new SQLITEDriver();
    string url = "restdb.db"; // file with DB
    static import std.file;
    /*if (std.file.exists(url))
        std.file.remove(url); */ // remove old DB file
    string[string] params;
    Dialect dialect = new SQLiteDialect();

    DataSource ds = new ConnectionPoolDataSourceImpl(driver, url, params);

    SessionFactory factory = new SessionFactoryImpl(schema, dialect, ds);

    DBInfo db = factory.getDBMetaData();
    {
        Connection conn = ds.getConnection();
        scope(exit) conn.close();
        db.updateDBSchema(conn, true, true);
    }

    sess = factory.openSession();
}