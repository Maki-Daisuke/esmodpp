//@jsmodpp
//@namespace myroom

//@include calendar.js

//@shared DEBUG_LEVEL
DEBUG_LEVEL = 0;

function DEBUG ( /* variable argumets */ ) {
    if ( DEBUG_LEVEL > 0 ) {
        document.write("DEBUG: ");
        document.write.apply(document, arguments);
    }
}

function CHECK ( /* variable argumets */ ) {
    if ( DEBUG_LEVEL > 10 ) {
        document.write("CHECK: ");
        document.write.apply(document, arguments);
    }
}

//@export getMonth
function getMonth ( ) {
    CHECK("`getMonth' is called.");
    return MONTH[(new Date).getMonth()];
}
