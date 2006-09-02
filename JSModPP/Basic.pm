package JSModPP::Basic;
our $VERSION = 0.1.3;

use JSModPP;
use Carp;
use File::Spec::Functions qw/catfile file_name_is_absolute/;


my $UnicodeLetter         = '\p{IsLu}\p{IsLl}\p{IsLt}\p{IsLm}\p{IsLo}\p{IsNl}';
my $UnicodeEscapeSequence = qr{\\u[0-9a-fA-F]{4}};
my $IdentifierStart       = qr{[\$_$UnicodeLetter]|$UnicodeEscapeSequence};
my $IdentifierPart        = qr{[\$_$UnicodeLetter\p{IsMn}\p{IsMc}\p{IsNd}\p{IsPc}]|$UnicodeEscapeSequence};
my $Identifier            = qr{(?>$IdentifierStart$IdentifierPart*)};

my %reserved = map{ $_ => 1 } qw{
    break     else        new        var
    case      finally     return     void
    catch     for         switch     while
    continue  function    this       with
    default   if          throw
    delete    in          try
    do        instanceof  typeof
    abstract  enum        int        short
    boolean   export      interface  static
    byte      extends     long       super
    char      final       native     synchronized
    class     float       package    throws
    const     goto        private    transient
    debugger  implements  protected  volatile
    double    import      public
};

sub is_identifier ($) {
    local $_ = shift;
    /^$Identifier$/o && not exists $reserved{$_};
}

sub parse_namespace ($) {
    local $_ = shift;
    my @id;
    foreach ( split /[\t\x{000B}\f \x{00A0}\p{IsZs}]*\.[\t\x{000B}\f \x{00A0}\p{IsZs}]*/ ) {
        croak "Invalid identifier: `$_'"  unless is_identifier $_;
        push @id, $_;
    }
    croak "Invalid namespace: `$_'" unless @id;
    \@id;
}


use base "JSModPP";
use fields qw{
    _buffer
    _jsmodpp
    _target
    _namespace
    _with
    _export
    _shared
};

sub new {
    my $class = shift;
    my JSModPP::Basic $self = $class->SUPER::new;
    $self->{_buffer}    = "var NAMESPACE = 'window';\n";
    $self->{_jsmodpp}   = undef;
    $self->{_target}    = "window";
    $self->{_namespace} = [];
    $self->{_with}      = [];
    $self->{_export}    = [];
    $self->{_shared}    = [];
    $self;
}

sub write {
    (my JSModPP::Basic $self, my @args) = @_;
    $self->{_buffer} .= join "", @args;
}

sub result {
    my JSModPP::Basic $self = shift;
    return $self->source  unless $self->{_jsmodpp};
    my $buf = "";
    foreach ( @{$self->{_namespace}} ) {
        my @names = @$_;
        my $name = shift @names;
        $buf .= qq{
            try {
                if ( !$name || (typeof $name != 'object' && typeof $name != 'function') ) $name = new Object();
            }
            catch ( e ) {
                $name = new Object();
            }
        };
        while ( @names ) {
            $name .= "." . shift @names;
            $buf .= "if ( !$name || (typeof $name != 'object' && typeof $name != 'function') ) $name = new Object();\n";
        }
    }
    foreach ( @{$self->{_shared}} ) {
        $buf .= "if ( $_ === undefined ) $_ = undefined;\n";
    }
    $buf .= "with ( function(){\n";
        foreach ( reverse @{$self->{_with}} ) {
            $buf .= "with ( $_ ) {\n";
        }
            $buf .= qq{
                return function () {
                    @{[ $self->{_buffer} ]}
                    return {
                        @{[ join ", ", map{"\$$_->{name}: $_->{name}"} @{$self->{_export}} ]}
                    };
                }();
            };
        $buf .= "}\n" x @{$self->{_with}};
    $buf .= "}() ) {\n";
        foreach ( @{$self->{_export}} ) {
            my ($ns, $name) = ($_->{namespace}, $_->{name});
            $buf .= "$ns.$name = \$$name;\n";
        }
    $buf .= "}\n";
    $buf;
}


sub text {
    (my JSModPP::Basic $self, undef, my $text) = @_;
    $self->write($text);
}

*{__PACKAGE__.'::@jsmodpp'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    if ( @args ) {
        croak "Version $args[0] is required, but this is only $VERSION"  if $args[0] > $VERSION;
    }
    $self->{_jsmodpp} = 1;
};

*{__PACKAGE__.'::@use-namespace'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    croak '@use-namespace takes just one argument.'  unless @args == 1;
    my $ns = parse_namespace $args[0];
    push @{$self->{_namespace}}, $ns;
    $ns = join ".", @$ns;
    $self->{_target} = $ns;
    $self->write("NAMESPACE = '$ns';\n");
};

*{__PACKAGE__.'::@export'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        croak "Invalid identifier: `$_'"  unless is_identifier $_;
        push @{$self->{_shared}}, "$target.$_";
        push @{$self->{_export}}, {namespace=>$target, name=>$_};
    }
};

*{__PACKAGE__.'::@shared'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        croak "Invalid identifier: `$_'"  unless is_identifier $_;
        push @{$self->{_shared}}, "$target.$_";
    }
};

*{__PACKAGE__.'::@with-namespace'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    foreach ( @args ) {
        my $ns = parse_namespace $_;
        push @{$self->{_namespace}}, $ns;
        push @{$self->{_with}}, join( ".", @$ns);
    }
};

*{__PACKAGE__.'::@namespace'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    croak '@namespace takes just one argument.'  unless @args == 1;
    my $ns = parse_namespace $args[0];
    push @{$self->{_namespace}}, $ns;
    $ns = join ".", @$ns;
    push @{$self->{_with}}, $ns;
    $self->{_target} = $ns;
    $self->write("NAMESPACE = '$ns';\n");
};

*{__PACKAGE__.'::@include'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    croak '@include requires one or more arguments.'  unless @args;
    foreach my $file ( @args ) {
        local *FILE;
        OPEN: unless ( open FILE, $file ) {
            unless ( file_name_is_absolute $file ) {
                foreach ( split /;/, $ENV{JS_INCLUDE} ) {
                    open(FILE, catfile $_, $file) and last OPEN;
                }
            };
            croak "Can't open file: $file";
        }
        read FILE, my $text, (stat FILE)[7];
        close FILE;
        $self->write($text);
    }
};



1;
