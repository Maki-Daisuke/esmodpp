use JSModPP;

unless ( @ARGV ) {
    print "Input JS file-name.\n";
    exit;
}

my $file = shift;
print JSModPP::Basic->file($file) || "Can't open file: $file";
