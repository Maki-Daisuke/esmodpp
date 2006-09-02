our $VERSION = 0.0.0;

use Cwd qw/ realpath /;
use File::Spec::Functions qw/ catfile file_name_is_absolute /;
use JSModPP::JSCat;

unless ( @ARGV ) {
    print "Input JS files.\n";
    exit;
}


sub error {
    print @_, "\n";
    exit 1;
}

sub search ($) {
    my $file = shift;
    local $@;
    my $abspath = eval{ realpath $file };
    return realpath $abspath  if not $@ and -f $abspath;
    # Duplicate application of `realpath' is necessary for Win32 systems.
    unless ( file_name_is_absolute $file ) {
        foreach ( split /;/, $ENV{JS_LIB} ) {
            local $@;
            $abspath = eval{ realpath catfile $_, $file };
            return realpath $abspath  if not $@ and -f $abspath;
        }
    }
    error "Cannot open `$file': No such file.";
}



my %files;   # $files{ABS_PATH}{code} / $files{ABS_PATH}{OK}
my %depend;  # $depend{REQUIRE, REQUIRED}
my $target;

while ( @ARGV ) {
    my $file = shift;
    my $abspath = search $file;
    next if $files{$abspath}{code};

    open FILE, $abspath  or error "Cannot open `$abspath': Access denied.";
    my $pp = JSModPP::JSCat->new;
    while ( <FILE> ) {
        local $@;
        eval{ $pp->chunk($_) };
        error $@=~/(.*?at )/s, "$file line $.." if $@;
    }
    close FILE;
    $files{$abspath}{code} = $pp->eof;
    
    foreach ( $pp->require ) {
        my $required = search $_;
        $depend{$abspath, $required} = 1;
        push @ARGV, $required;
    }
}

my @output;
sub order {
    my ($file, @path) = @_;
    foreach ( @path ) {
        if ( $_ eq $file ) {
            error "Cyclic dependency detected: ", join(" -> ", @path, $file), "\n";
        }
    }
    return if $files{$file}{OK};
    foreach ( keys %files ) {
        order($_, @path, $file)  if $depend{$file, $_};
    }
    push @output, $file;
    $files{$file}{OK} = 1;
}
order $_  foreach keys %files;

foreach ( @output ) {
    print "$files{$_}{code}\n";
}
