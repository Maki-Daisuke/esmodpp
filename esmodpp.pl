use ESModPP;

unless ( @ARGV ) {
    print "Input an ECMAScript sourse file.\n";
    exit;
}

my $file = shift;
local $@;
my $result = eval{
    ESModPP->file($file)  or print(STDERR "Can't open file: $file\n"), exit(1);
};
if ( $@ ) {
    $@ =~ /(.*?) at line (\d+)/s;
    print STDERR "$1 at $file line $2\n";
    exit(1);
}
print $result;
