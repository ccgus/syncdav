Array.prototype.remove = function(e) {
    for (var i = 0; i < this.length; i++) {
        if (e == this[i]) { return this.splice(i, 1); }
    }
};

String.prototype.startsWith = function(str){
    return (this.indexOf(str) === 0);
}


String.prototype.stripNewline = function(str){
    
    var trimLoc = this.indexOf("\r\n");
    
    if (trimLoc < 0) {
        trimLoc = this.indexOf("\n");
    }
    
    if (trimLoc < 0) {
        trimLoc = this.indexOf("\r");
    }
    
    if (trimLoc > 0) {
        return this.substring(0, trimLoc)
    }
    
    return this;
}

