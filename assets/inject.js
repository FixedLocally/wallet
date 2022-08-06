function(key, bogusKeys) {
    window.phantom = (function() {
        let id = 0;
        let pendingRpcs = {};
        let realMessageHandler = window[`messageHandler${key}`];
        let eventHandlers = {};
        let injectedScope = {};

        // instance methods
        function newCall(Cls, args) {
            return new (Function.prototype.bind.apply(Cls, [Cls, ...args]));
            // or even
            // return new (Cls.bind.apply(Cls, arguments));
            // if you know that Cls.bind has not been overwritten
        }
        function rpc(method, args) {
            ++id;
            realMessageHandler.postMessage(JSON.stringify({method, args, id}));
            return new Promise((resolve, reject) => {
                pendingRpcs[id] = {resolve, reject};
            });
        }
        function parseRpcResult(result) {
            let _result;
            if (result.type != null) {
                _result = newCall(solanaWeb3[result.type], result.value);
            } else {
                _result = result.value;
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
            pendingRpcs[rpcId].reject(parseRpcResult(ex));
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
        function bogusRpc() { console.log("bogus") } // does precisely nothing
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
        let phantom = {
            solana: {
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
                on: function(trigger, callback) {
                    let callbacks = eventHandlers[trigger] || [];
                    callbacks.push(callback);
                    eventHandlers[trigger] = callbacks;
                },
                off: function(trigger, callback) {
                    let callbacks = eventHandlers[trigger] || [];
                    callbacks = callbacks.filter(cb => cb !== callback);
                    eventHandlers[trigger] = callbacks;
                },
                isPhantom: true,
            },
        };
        // getters
        phantom.solana.__defineGetter__("publicKey", function() {
            return injectedScope["publicKey"];
        });
        return phantom;
    })();
}