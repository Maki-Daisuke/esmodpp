//@jsmodpp
//@namespace data.functional

var proto = Array.prototype;

proto.copy = function ( ) {
    var a = [];
    for ( var i=0;  i < this.length;  i++ ) a.push(this[i]);
    return a;
};

proto.equals = function ( a ) {
    if ( !(a instanceof Array)   ) return false;
    if ( a.length != this.length ) return false;
    for ( var i=0, j=0;  i < this.length;  i++, j++ ) {
        if ( this[i] !== a[j] ) return false;
    }
    return true;
};

proto.head = function ( ) {
    return this[0];
};

proto.tail = function ( ) {
    return this[this.length-1];
}

proto.filter = function ( f ) {
    var a = [];
    for ( var i=0;  i < this.length;  i++ ) {
        if ( f(this[i]) ) a.push(this[i]);
    }
    return a;
};

proto.map = function ( f ) {
    var a = [];
    for ( var i=0;  i < this.length;  i++ ) {
        try {
            a.push(f(this[i]));
        }
        catch ( e ) {
            if ( e instanceof ListReturnError ) {
                a.push.apply(a, e.args);
            }
            else if ( e instanceof DiscontinueError ) {
                a.push.apply(a, e.args);
                return a;
            }
            else {
                throw e;
            }
        }
    }
    return a;
};

proto.foreach = function ( f ) {
    for ( var i=0;  i < this.length;  i++ ) {
        try {
            f(this[i]);
        }
        catch ( e ) {
            if ( e instanceof ListReturnError ) {
                // Do nothimg.
            }
            else if ( e instanceof DiscontinueError ) {
                return;
            }
            else {
                throw e;
            }
        }
    }
};

proto.foldl = function ( f, s ) {
    for ( var i=0;  i < this.length;  i++ ) {
        try {
            s = f(s, this[i]);
        }
        catch ( e ) {
            if ( e instanceof ListReturnError ) {
                s = e.args[0];
            }
            else if ( e instanceof DiscontinueError ) {
                return e.args[0];
            }
            else {
                throw e;
            }
        }
    }
    return s;
};

proto.foldl1 = function ( f ) {
    if ( !this.length ) return;
    var s = this[0];
    for ( var i=1;  i < this.length;  i++ ) {
        try {
            s = f(s, this[i]);
        }
        catch ( e ) {
            if ( e instanceof ListReturnError ) {
                s = e.args[0];
            }
            else if ( e instanceof DiscontinueError ) {
                return e.args[0];
            }
            else {
                throw e;
            }
        }
    }
    return s;
};

proto.foldr = function ( f, s ) {
    for ( var i=this.length-1;  i >= 0;  i-- ) {
        try {
            s = f(this[i], s);
        }
        catch ( e ) {
            if ( e instanceof ListReturnError ) {
                s = e.args[0];
            }
            else if ( e instanceof DiscontinueError ) {
                return e.args[0];
            }
            else {
                throw e;
            }
        }
    }
    return s;
};

proto.foldr1 = function ( f ) {
    if ( !this.length ) return;
    var s = this[this.length-1];
    for ( var i=this.length-2;  i >= 0;  i-- ) {
        try {
            s = f(this[i], s);
        }
        catch ( e ) {
            if ( e instanceof ListReturnError ) {
                s = e.args[0];
            }
            else if ( e instanceof DiscontinueError ) {
                return e.args[0];
            }
            else {
                throw e;
            }
        }
    }
    return s;
};



function list_return ( /* variable arguments */ ) {
    throw new ListReturnError(arguments);
}

function ListReturnError ( args ) {
    this.args    = args;
    this.message = "invalid use of `multi_return' (used outside of map)";
}

ListReturnError.prototype.name = NAMESPACE + ".ListReturnError";


function discontinue ( /* variable arguments */ ) {
    throw new DiscontinueError(arguments);
}

function DiscontinueError ( args ) {
    this.args = args;
    this.message = "invalid use of `discontinue'";
}

DiscontinueError.prototype.name = NAMESPACE + ".DiscontinueError";

