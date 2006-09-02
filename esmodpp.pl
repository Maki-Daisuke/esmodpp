use ESModPP;

unless ( @ARGV ) {
    print "Input an ECMAScript sourse file.\n";
    exit;
}

my $file = shift;
open FILE, $file  or print("Can't open file: $file\n"), exit(1);
my $pp = new ESModPP;
local $@;
my $result = eval{
    $pp->chunk($_) while <FILE>;
    $pp->eof;
};
print($@=~/(.*? at )/s, "$file line $..\n"), exit(1)  if $@;
print $result;
