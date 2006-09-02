//@jsmodpp
//@namespace data.iterator

function Iterator ( ) {
    // This is kind of abstract class.
    // Sub-classes should implement appropreate methods.
}

var proto = Iterator.prototype;


// Returns copy of this iterator.
// The default implementation makes shallow-copy.
proto.copy = function ( ) {
    // shollow copy
    var copy = new this.constructor();
    for ( var i in this ) {
        if ( this.hasOwnProperty(i) ) copy[i] = this[i];
    }
    return copy;
};

// Returns 0 if both this iterator and the argument points to the same element,
// -1 if the element this iterator points to precedes the one of the argument,
// 1 otherwize.
// The default implementation is based on `equals', `next' and `isTail' methods.
proto.compareTo = function ( r ) {
    var l = this;
    if ( l.equals(r) ) return 0;
    while ( !l.isTail() ) {
        l = l.next();
        if ( l.equals(r) ) return -1;
    }
    return 1;
};

// Returns true if both this iterator and the argument points to the same element,
// false otherwise.
// The default implementation is based on `compareTo' method.
proto.equals = function ( another ) {
    this.compareTo(another) == 0;
};

proto.distance = function ( another ) {
    if ( this.top != another.top ) throw new IllegalStateError("Two iterators belong to different lists.");
    var l = this.pos;
    var r = another.pos;
    if ( l == r ) return 0;
    for ( ;  l != this.top;  l=l.next ) {
        if ( l == r ) return -1;
    }
    return 1;
};

proto.isHead = function ( ) {
    return this.pos != this.top.next;
};

proto.isTail = function ( ) {
    return this.pos == this.top;
};

proto.value = function ( ) {
    return this.pos.value;
};

proto.assign = function ( v ) {
    if ( this.isTail() ) throw new IllegalStateError("can't assign at the tail of list");
    var old = this.pos.value;
    this.pos.value = v;
    return old;
};

proto.next = function ( ) {
    if ( this.isTail() ) throw new NoSuchElementError("no next element");
    do{ this.pos = this.pos.next } while(this.pos.removed);
    return this.pos.value;
};

proto.previous = function ( ) {
    if ( this.isHead() ) throw new NoSuchElementError("no previous element");
    do{ this.pos = this.pos.prev } while(this.pos.removed);
    return this.pos.value;
};

proto.insert = function ( v ) {
    return this.pos.push(v);
};

proto.remove = function ( ) {
    if ( this.isTail() ) throw new IllegalStateError("can't remove at the tail of list");
    return this.pos.next.pop();
};



//@export NotImplementedError
NotImplementedError = function ( m ) {
    if ( m !== undefined ) this.message = m;
};

NotImplementedError.prototype.name = "NotImplementedError";


//@export NoSuchElementError
NoSuchElementError = function ( m ) {
    if ( m !== undefined ) this.message = m;
};

NoSuchElementError.prototype.name = "NoSuchElementError";


//@export IllegalStateError
IllegalStateError = function ( m ) {
    if ( m !== undefined ) this.message = m;
};

IllegalStateError.prototype.name = "IllegalStateError";
