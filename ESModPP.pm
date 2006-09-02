package ESModPP;
our $VERSION = 0.9.0;

use strict;
no strict 'refs';
no warnings 'uninitialized';

use ESModPP::Parser qw/:all/;
use Exporter;
use Carp;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

use constant DEFAULT_NAMESPACE => "window";

use base qw/Exporter ESModPP::Parser/;
our @EXPORT_OK   = qw/version_cmp/;
our @EXPORT_TAGS = (all => \@EXPORT_OK);

use fields qw{
    _buffer
    _esmodpp
    _version
    _target
    _namespace
    _with
    _export
    _shared
};

sub new : method {
    my $class = shift;
    my ESModPP $self = $class->SUPER::new;
    $self->{_buffer}    = "";
    $self->{_esmodpp}   = undef;
    $self->{_version}   = undef;
    $self->{_target}    = undef;
    $self->{_namespace} = {};
    $self->{_with}      = [];
    $self->{_export}    = [];
    $self->{_shared}    = [];
    $self;
}

my $register_ns = sub : method {
    my ESModPP $self = shift;
    my $ns = shift;
    my @id = parse_namespace $ns  or croak "Invalid namespace: `$ns'";
    $ns = join ".", @id;
    ${$self->{_namespace}}{$ns} = 1;
    $ns;
};

my $check_target = sub : method {
    my ESModPP $self = shift;
    return if $self->{_target};
    $self->$register_ns(DEFAULT_NAMESPACE);
    $self->{_target} = DEFAULT_NAMESPACE;
};

sub version : method {
    my ESModPP $self = shift;
    $self->{_version};
}

sub write : method {
    (my ESModPP $self, my @args) = @_;
    $self->{_buffer} .= join "", @args;
}

sub result : method {
    my ESModPP $self = shift;
    return $self->source  unless $self->{_esmodpp};
    my $buf = "";
    foreach ( keys %{$self->{_namespace}} ) {
        my @names = parse_namespace $_;
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
                    var VERSION @{[ defined $self->{_version} ? "= '$self->{_version}'" : "" ]};
                    var NAMESPACE;
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


sub text : method {
    (my ESModPP $self, undef, my $text) = @_;
    $self->write($text);
}

*{__PACKAGE__.'::@esmodpp'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    if ( @args ) {
        croak '@esmodpp takes at most one argument'                                 unless @args == 1;
        local $_ = shift @args;
        croak "Invalid version string: `$_'"                                        unless /^\d+(?>\.\d+)*$/;
        croak sprintf "ESModPP %s is required, but this is only %vd", $_, $VERSION  if version_cmp($_, $VERSION) > 0;
    }
    $self->{_esmodpp} = 1;
};

*{__PACKAGE__.'::@version'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    croak '@version takes just one argument'  unless @args == 1;
    local $_ = shift @args;
    croak "Invalid version string: `$_'"      unless /^\d+(?>\.\d+)*$/;
    croak '@version appears more than once'   if defined $self->{_version};
    $self->{_version} = $_;
};

*{__PACKAGE__.'::@use-namespace'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    croak '@use-namespace takes just one argument'  unless @args == 1;
    my $ns = $self->$register_ns($args[0]);
    $self->{_target} = $ns;
    $self->write("NAMESPACE = '$ns';\n");
};

*{__PACKAGE__.'::@with-namespace'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    croak '@with-namespace requires one or more arguments'  unless @args;
    foreach ( @args ) {
        my $ns = $self->$register_ns($_);
        push @{$self->{_with}}, $ns;
    }
};

*{__PACKAGE__.'::@namespace'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    my $text = shift;
    croak '@namespace takes just one argument.'  unless @args == 1;
    my $use  = '@use-namespace';
    my $with = '@with-namespace';
    $self->$use([$args[0]], $text);
    $self->$with([$args[0]], $text);
};

*{__PACKAGE__.'::@export'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$check_target;
    my $target = $self->{_target};
    foreach ( @args ) {
        croak "Invalid identifier: `$_'"  unless is_identifier $_;
        push @{$self->{_shared}}, "$target.$_";
        push @{$self->{_export}}, {namespace=>$target, name=>$_};
    }
};

*{__PACKAGE__.'::@shared'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$check_target;
    my $target = $self->{_target};
    foreach ( @args ) {
        croak "Invalid identifier: `$_'"  unless is_identifier $_;
        push @{$self->{_shared}}, "$target.$_";
    }
};

*{__PACKAGE__.'::@include'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    croak '@include requires one or more arguments.'  unless @args;
    foreach my $file ( @args ) {
        local *FILE;
        OPEN: unless ( open FILE, $file ) {
            unless ( file_name_is_absolute $file ) {
                foreach ( split /;/, $ENV{ES_INCLUDE} ) {
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



sub version_cmp {
    our (@l, @r);
    local (*l, *r) = map{
        my @nums;
        local $_ = $_;
        $_ = sprintf "%vd", $_  unless /^[0-9]/;
        [ split /\./ ]
    } @_;
    while ( @l || @r ) {
        my $cmp = shift @l <=> shift @r;
        return $cmp  if $cmp;
    }
    return 0;
}



1;
