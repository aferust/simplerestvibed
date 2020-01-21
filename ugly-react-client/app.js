import React, {Component} from 'react';
import logo from './logo.svg';
import './App.css';

const apiRoot = 'http://localhost:8080/';

class LoginFrame extends Component {
    constructor(props){
        super(props);
        
        this.handleChange_u = this.handleChange_u.bind(this);
        this.handleChange_p = this.handleChange_p.bind(this);
        this.handleLogin = this.handleLogin.bind(this);
        this.handlelogOut = this.handlelogOut.bind(this);

        this.state = {
            username: '',
            password: '',
            loggedIn: false
        };
    }
    handleChange_u(event) {
        this.setState({username: event.target.value});
    }
    handleChange_p(event) {
        this.setState({password: event.target.value});
    }
    handleLogin(event) {
        event.preventDefault();
        
        const auth = new Buffer(this.state.username +':'+ this.state.password).toString('base64');
        fetch(apiRoot + 'loggedin/gettoken', {
            method: 'POST',
            headers: {
                'Authorization': 'Basic ' + auth,
                'Content-Type': 'application/json'
            }
        })
        .then((response) => response.json())
        .then((mjson) => {
            console.log(mjson);
            localStorage.setItem('token', mjson.token);
            this.setState({loggedIn: true});
        })
        .catch((error) => { });
    }

    handlelogOut(event){
        localStorage.setItem('token', null);
        this.setState({loggedIn: false});

    }

    render(){
        if (!this.state.loggedIn)
        return (
            <form>
                <label>
                    username:
                    <input type="text" name="username" value={this.state.username} onChange={this.handleChange_u} />
                </label>
                < br />
                <label>
                    password:
                    <input type="password" name="password" value={this.state.password}  onChange={this.handleChange_p} />
                </label>
                < br />
                <input type="submit" value="login" onClick={this.handleLogin} />
            </form>
        );

        return (
            <div>
                <a href="#" onClick={this.handlelogOut}>Log out</a>
                <br />
                <ShowUpdateUserInfo userdata=""/>
            </div>
        );
    }
}

class SignUp extends Component {
    constructor(props){
        super(props);
        this.handleChange_u = this.handleChange_u.bind(this);
        this.handleChange_p = this.handleChange_p.bind(this);
        this.handleSignUp = this.handleSignUp.bind(this);

        this.state = {
            username: '',
            password: ''
        };
    }
    handleChange_u(event) {
        this.setState({username: event.target.value});
    }
    handleChange_p(event) {
        this.setState({password: event.target.value});
    }
    handleSignUp(event){
        event.preventDefault();
        const uname = this.state.username;
        const pass = this.state.password;
        fetch(apiRoot + 'newuser', {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: `{"username": "${uname}", "password": "${pass}"}`
        })
        .then((response) => response.json())
        .then((mjson) => {
            console.log(mjson);
            localStorage.setItem('token', mjson.token);
        })
        .catch((error) => { });
    }

    render(){
        return (
            <form>
                <label>
                    username:
                    <input type="text" name="username" value={this.state.username} onChange={this.handleChange_u} />
                </label>
                < br />
                <label>
                    password:
                    <input type="password" name="password" value={this.state.password}  onChange={this.handleChange_p} />
                </label>
                < br />
                <input type="submit" value="Sign up" onClick={this.handleSignUp} />
            </form>
        );
    }
}

class ShowUpdateUserInfo extends Component {
    constructor(props){
        super(props);

        this.handleChange_u = this.handleChange_u.bind(this);
        this.handleReceive = this.handleReceive.bind(this);
        this.handleUpdate = this.handleUpdate.bind(this);

        this.state = {
            userdata: props.userdata
        };
    }

    handleChange_u(event){
        this.setState({userdata: event.target.value});
    }

    handleUpdate(event){
        const token = localStorage.getItem('token');
        const auth = new Buffer(token +':unused').toString('base64');
        const udata = this.state.userdata;

        fetch(apiRoot + 'loggedin/setuserdata', {
            method: 'POST',
            headers: {
                'Authorization': 'Basic ' + auth,
                'Content-Type': 'application/json'
            },
            body: `{"userdata": "${udata}"}`,
        })
        .then((response) => response.json())
        .then((mjson) => {
            console.log(mjson);
            localStorage.setItem('token', mjson.token); // update token at the end of each api call
                                                        // thus, session time will extend
        })
        .catch((error) => { });
    }

    handleReceive(event){
        const token = localStorage.getItem('token');
        const auth = new Buffer(token +':unused').toString('base64');
        fetch(apiRoot + 'loggedin/getuserdata', {
            method: 'POST',
            headers: {
                'Authorization': 'Basic ' + auth,
                'Content-Type': 'application/json'
            }
        })
        .then((response) => response.json())
        .then((mjson) => {
            console.log(mjson);
            this.setState({ userdata: mjson.userdata });
            localStorage.setItem('token', mjson.token); // update token at the end of each api call
        })
        .catch((error) => { });
    }

    render(){
        return(
            <label>
                User data:
                <input type="text" name="userdata" value={this.state.userdata} onChange={this.handleChange_u} />
                <br />
                <a href="#" onClick={this.handleUpdate}>Update in DB</a>
                <br />
                <a href="#" onClick={this.handleReceive}>Receive data from api</a>
            </label>
        );
    }
}

class App extends Component {
    constructor(props){
        super(props);
    }

    render() {
        return (
            <div className="App">
              <header className="App-header">
                <img src={logo} className="App-logo" alt="logo" />
                <p>
                    <SignUp />
                    <br />
                    <LoginFrame />
                </p>
                <a
                  className="App-link"
                  href="https://reactjs.org"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Learn React
                </a>
              </header>
            </div>
          );
    }
    

}

export default App;
