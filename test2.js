//@namespace my.room
//@version 1.2.3
//@include calendar.js

//@esmodpp 0.9.1

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

//@esmodpp off

//@export getMonth
function getMonth ( ) {
    CHECK("`getMonth' is called.");
    return MONTH[(new Date).getMonth()];
}
