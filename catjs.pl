unless ( @ARGV ) {
    print "Input dependency file.\n";
    exit;
}

my %files;
my %depend;  # $depend{'require', 'required'}
my $target;
while ( <> ) {
    chomp;
    s/\s*(?:#.*)?$//;
    next unless $_;
    if ( /^\t/ ) {
        die "Syntax error: No target has been specified yet."  unless $target;
        s/^\s+//;
        $files{$_} = 0;
        $depend{$target, $_} = 1;
    }
    else {
        s/^\s+//;
        $files{$_} = 0;
        $target = $_;
    }
}


my @output;
sub order {
    my ($file, @path) = @_;
    foreach ( @path ) {
        if ( $_ eq $file ) {
            print "ERROR: Cyclic dependency: ", join(" -> ", @path, $file), "\n";
            exit;
        }
    }
    return if $files{$file};
    foreach ( keys %files ) {
        order($_, @path, $file)  if $depend{$file, $_};
    }
    push @output, $file;
    $files{$file} = 1;
}
order $_  foreach keys %files;

@ARGV = @output;
print while <>;
