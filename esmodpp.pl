use JSModPP::Basic;

unless ( @ARGV ) {
    print "Input JS file-name.\n";
    exit;
}

my $file = shift;
open FILE, $file  or print("Can't open file: $file\n"), exit(1);
my $pp = new JSModPP::Basic;
local $@;
eval{ $pp->chunk($_) while <FILE> };
print($@=~/(.*?\bat )/s, "$file line $..\n"), exit(1)  if $@;
print $pp->eof;
