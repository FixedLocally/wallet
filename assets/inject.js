function(key, bogusKeys) {
    (function() {
        let id = 0;
        let pendingRpcs = {};
        let realMessageHandler = window[`messageHandler${key}`];
        let eventHandlers = {};
        let injectedScope = {
            publicKey: null,
            isConnected: false,
        };

        // instance methods
        function newCall(Cls, args) {
            return new (Function.prototype.bind.apply(Cls, [Cls, ...args]));
            // or even
            // return new (Cls.bind.apply(Cls, arguments));
            // if you know that Cls.bind has not been overwritten
        }
        function rpc(method, params) {
            ++id;
            realMessageHandler.postMessage(JSON.stringify({method, params, id}));
            return new Promise((resolve, reject) => {
                pendingRpcs[id] = {resolve, reject};
            });
        }
        function parseRpcResult(result) {
            let _result;
            console.log("parse", result);
            if (result.type != null) {
                _result = newCall(solanaWeb3[result.type], result.value);
            } else {
                _result = result.value;
                console.log("nest", _result);
                if ("object" === typeof _result) {
                    for (let key in _result) {
                        _result[key] = parseRpcResult(_result[key]);
                    }
                }
            }
            return _result;
        }
        function resolveRpc(rpcId, result) {
            console.log("resolveRpc", rpcId, result);
            pendingRpcs[rpcId].resolve(parseRpcResult(result));
            delete pendingRpcs[rpcId];
        }
        function rejectRpc(rpcId, ex) {
            console.log("rejectRpc", rpcId, ex);
            pendingRpcs[rpcId].reject(ex);
            delete pendingRpcs[rpcId];
        }
        function eventIngestion(type, evt, setters) {
            console.log("eventIngestion", type, evt);
            let arg = parseRpcResult(evt);
            for (let i in setters) {
                injectedScope[i] = parseRpcResult(setters[i]);
            }
            if (eventHandlers[type] != null) {
                eventHandlers[type].map(handler => handler(arg));
            }
        }
        function bogusRpc() {} // does precisely nothing
        function setup() {
            resolveRpc.toString = () => "uwu";
            rejectRpc.toString = () => "uwu";
            bogusRpc.toString = () => "uwu";
            window[`resolveRpc${key}`] = resolveRpc;
            window[`rejectRpc${key}`] = rejectRpc;
            window[`eventIngestion${key}`] = eventIngestion;
            for (let bogusKey of bogusKeys) {
                window[`resolveRpc${bogusKey}`] = bogusRpc;
                window[`rejectRpc${bogusKey}`] = bogusRpc;
                window[`eventIngestion${bogusKey}`] = bogusRpc;
            }
            alert(1);
        }

        setup();

        // public methods
        let solana = {
            exit: function() {
                return rpc("exit", {});
            },
            print: function(message) {
                return rpc("print", {"message": message});
            },
            createError: function(message) {
                return rpc("create_error", {});
            },
            connect: function(opts) {
                return rpc("connect", opts);
            },
            disconnect: function(opts) {
                return rpc("disconnect", opts);
            },
            signTransaction: function(opts) {
                return rpc("signTransaction", opts);
            },
            on: function(trigger, callback) {
                console.log(new Error().stack);
                let callbacks = eventHandlers[trigger] || [];
                callbacks.push(callback);
                eventHandlers[trigger] = callbacks;
            },
            off: function(trigger, callback) {
                let callbacks = eventHandlers[trigger] || [];
                callbacks = callbacks.filter(cb => cb !== callback);
                eventHandlers[trigger] = callbacks;
            },
            request: function(opts) {
                if (!opts.method) return Promise.reject({code: -32000, message: "Invalid Input"});
                return rpc(opts.method, opts.params);
            },
            _handleDisconnect: function() {},
            isPhantom: true,
        };
        let phantom = {solana};
        // getters
        phantom.solana.__defineGetter__("publicKey", function() {
            return injectedScope["publicKey"];
        });
        phantom.solana.__defineGetter__("isConnected", function() {
            return injectedScope["isConnected"];
        });
        window.__defineGetter__("solana", () => solana);
        window.__defineGetter__("phantom", () => phantom);

        // debug
//        window.injectedScope = injectedScope;
//        window.eventHandlers = eventHandlers;
    })();
}