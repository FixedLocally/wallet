function createPhantom(key) {
    console.log("create phantom", key);
    window.phantom = (function() {
        let id = 0;
        function rpc(method, args) {
            ++id;
            window[`messageHandler${key}`].postMessage(JSON.stringify({method, args, id}));
        }
        return {
            exit: function() {
               rpc("print", "from phantom");
            },
       };
    })();
    for (let i in window) {
        console.log(i);
        if (i.startsWith("messageHandler")) {
            window[i].postMessage(JSON.stringify({method: "print", args: "from inject"}));
        }
    }
    // remove this function from existence
    delete createPhantom;
}