//@jsmodpp
//@namespace my.room

//@include calendar.js

//@shared DEBUG_LEVEL
DEBUG_LEVEL = 0;

function DEBUG ( /* variable argumets */ ) {
    if ( DEBUG_LEVEL > 0 ) {
        document.write("DEBUG: ");
        for ( var i=0;  i < arguments.length;  i++ ) {
            document.write(arguments[0]);
        }
        document.write("<br>\n");
    }
}

function CHECK ( /* variable argumets */ ) {
    if ( DEBUG_LEVEL >= 2 ) {
        document.write("CHECK: ");
        for ( var i=0;  i < arguments.length;  i++ ) {
            document.write(arguments[0]);
        }
        document.write("<br>\n");
    }
}

//@export getMonth
function getMonth ( ) {
    CHECK("`getMonth' is called.");
    return MONTH[(new Date).getMonth()];
}
