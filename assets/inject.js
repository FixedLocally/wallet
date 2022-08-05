window.createPhantom = function(key, bogusKeys) {
    window.phantom = (function() {
        let id = 0;
        let pendingRpcs = {};
        let realMessageHandler = window[`messageHandler${key}`];

        // instance methods
        function rpc(method, args) {
            ++id;
            realMessageHandler.postMessage(JSON.stringify({method, args, id}));
            return new Promise((resolve, reject) => {
                pendingRpcs[id] = {resolve, reject};
            });
        }
        function resolveRpc(rpcId, result) {
            console.log("resolveRpc", rpcId, result);
            pendingRpcs[rpcId].resolve(result);
            delete pendingRpcs[rpcId];
        }
        function rejectRpc(rpcId, ex) {
            pendingRpcs[rpcId].reject(ex);
            delete pendingRpcs[rpcId];
        }
        function bogusRpc() { console.log("bogus") } // does precisely nothing
        function setup() {
            resolveRpc.toString = () => "uwu";
            rejectRpc.toString = () => "uwu";
            bogusRpc.toString = () => "uwu";
            window[`resolveRpc${key}`] = resolveRpc;
            window[`rejectRpc${key}`] = rejectRpc;
            for (let bogusKey of bogusKeys) {
                window[`resolveRpc${bogusKey}`] = bogusRpc;
                window[`rejectRpc${bogusKey}`] = bogusRpc;
            }
        }

        setup();

        // public methods
        return {
            exit: function() {
               return rpc("exit", {});
            },
            print: function(message) {
               return rpc("print", {"message": message});
            },
            createError: function(message) {
               return rpc("create_error", {});
            },
        };
    })();
    // remove this function from existence
    delete window.createPhantom;
}