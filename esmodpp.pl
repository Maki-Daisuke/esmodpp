use utf8;
use ESModPP;
#use XML::DOM;
use XML::Generator;
use Getopt::Compact;
use Symbol qw/qualify_to_ref/;


my $go = Getopt::Compact->new(
    name   => "EcmaScript MODularizing PreProcessor",
    args   => "FILE...",
    struct => [ [[qw/F filter/], "filter mode"] ]
);
local *opts = $go->opts;


sub error {
    print STDERR @_, "\n";
    exit 1;
}

sub branch {
    my ($src, $eso, $esd) = @_;
    my $p = ESModPP->new;
    binmode $src, ":raw";
    local $/;
    $p->handle($src);
    binmode $eso, ":raw";
    print $eso $p->eof;
    
=cut
    my $xml = new XML::DOM::Document;
    $xml->setXMLDecl($xml->createXMLDecl("1.0", "UTF-8"));
    my $root = $xml->appendChild($xml->createElement("esd"));
    $root->setAttribute("version", "1.0");
    my $mod = $root->appendChild($xml->createElement("module"));
    $mod->setAttribute("version", $p->version);
    foreach ( qw/require extend/ ) {
        my $mods = $p->$_;
        while ( my ($module, $version) = each %$mods ) {
            my $e = $mod->appendChild($xml->createElement($_));
            $e->setAttribute("module", $module);
            $e->setAttribute("version", $version || 0);
        }
    }
    print $esd $xml->toString;
=cut
    my $gen = XML::Generator->new(":pretty");
    local (*require, *extend);
    *require = [];
    *extend  = [];
    foreach ( qw/require extend/ ) {
        my $mods = $p->$_;
        while ( my ($module, $version) = each %$mods ) {
            push @$_, $gen->require({ module  => $module,
                                      version => $version || 0 });
        }
    }
    binmode $esd, ":utf8";
    print $esd $gen->xmldecl(version => "1.0", encoding => "UTF-8"),
               $gen->esd( { version => "1.0" },
                   $gen->module( { version => $p->version || 0 },
                       @require,
                       @extend,
                   )
               );
}



if ( $opts{filter} ) {
    branch \*STDIN, \*STDOUT, \*STDERR;
    exit;
}


unless ( @ARGV ) {
    print $go->usage;
    exit;
}

foreach my $file ( @ARGV ) {
    open my $src, $file                        or error "Can't open file: `$file'";
    (my $file_base = $file) =~ s/\.[^.]*$//s;
    open my $eso, ">$file_base.eso"            or error "Can't open file: `$file_base.eso'";
    open my $esd, ">$file_base.esd"            or error "Can't open file: `$file_base.esd'";
    local $@;
    eval{ branch $src, $eso, $esd };
    if ( $@ ) {
        $@ =~ /(.*?) at line (\d+)/s;
        print STDERR "$1 at $file line $2\n";
        exit 1;
    }
}

