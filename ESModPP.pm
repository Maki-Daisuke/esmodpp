package ESModPP;
our $VERSION = 0.9.1;

use strict;
no strict 'refs';
no warnings 'uninitialized';

use ESModPP::Parser qw/:all/;
use Exporter;
use Carp;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

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
    _global
    _shared
};

sub new : method {
    my $class = shift;
    my ESModPP $self = $class->SUPER::new;
    $self->{_buffer}    = "";
    $self->{_esmodpp}   = undef;
    $self->{_version}   = undef;
    $self->{_target}    = "GLOBAL";
    $self->{_namespace} = {};
    $self->{_with}      = [];
    $self->{_export}    = [];
    $self->{_global}    = [];
    $self->{_shared}    = [];
    $self;
}

my $register_ns = sub : method {
    my ESModPP $self = shift;
    my $ns = shift;
    my @id = parse_namespace $ns  or croak "Invalid namespace: `$ns'";
    $ns = join ".", @id;
    ${$self->{_namespace}}{$ns} = \@id;
    $ns;
};

sub version : method {
    my ESModPP $self = shift;
    $self->{_version};
}

sub active : method {
    my ESModPP $self = shift;
    $self->{_esmodpp};
}

sub write : method {
    (my ESModPP $self, my @args) = @_;
    $self->{_buffer} .= join "", @args;
}

sub result : method {
    my ESModPP $self = shift;
    return $self->{_buffer}  unless defined $self->{_esmodpp};
    my $buf = "(function(){\n";  # Top-level closure, which ensures that this-value refers the Global Object.
    foreach ( @{$self->{_global}} ) {
        $buf .= "    if ( this.$_ === undefined ) this.$_ = undefined;\n";
    }
    foreach ( values %{$self->{_namespace}} ) {
        my @names = @$_;
        my $name = "this";
        while ( @names ) {
            $name .= "." . shift @names;
            $buf .= "    if ( !$name || (typeof $name != 'object' && typeof $name != 'function') ) $name = new Object();\n";
        }
    }
    foreach ( @{$self->{_shared}} ) {
        $buf .= "    if ( this.$_ === undefined ) this.$_ = undefined;\n";
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
    $buf .= "}.call(null) ) {\n";
    foreach ( @{$self->{_export}} ) {
        my ($ns, $name) = ($_->{namespace}, $_->{name});
        $ns = $ns ? "$ns.$name" : $name;
        $buf .= "    this.$ns = \$$name;\n";
    }
    $buf .= "}\n";     # End of with
    $buf .= "}).call(null);\n";  # The end of the top-level closure.
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
        if ( /^off$/i ) {
            if ( $self->{_esmodpp} ) { $self->{_esmodpp} = "" }
            else                     { $self->write(shift)    }
            return;
        }
        croak "Invalid version string: `$_'"                                        unless /^\d+(?>\.\d+)*$/;
        croak sprintf "ESModPP %s is required, but this is only %vd", $_, $VERSION  if version_cmp($_, $VERSION) > 0;
    }
    $self->{_esmodpp} = 1;
};

*{__PACKAGE__.'::@version'} = sub : method {
    my ESModPP $self = shift;
    return $self->write($_[1])  unless $self->active;
    my @args = @{shift()};
    croak '@version takes just one argument'  unless @args == 1;
    local $_ = shift @args;
    croak "Invalid version string: `$_'"      unless /^\d+(?>\.\d+)*$/;
    croak '@version appears more than once'   if defined $self->{_version};
    $self->{_version} = $_;
};

*{__PACKAGE__.'::@use-namespace'} = sub : method {
    my ESModPP $self = shift;
    return $self->write($_[1])  unless $self->active;
    my @args = @{shift()};
    croak '@use-namespace takes just one argument'  unless @args == 1;
    my $ns = $self->$register_ns($args[0])          unless $args[0] eq "GLOBAL";
    $self->{_target} = $ns;
    $self->write("NAMESPACE = '$ns';\n");
};

*{__PACKAGE__.'::@with-namespace'} = sub : method {
    my ESModPP $self = shift;
    return $self->write($_[1])  unless $self->active;
    my @args = @{shift()};
    croak '@with-namespace requires one or more arguments'  unless @args;
    foreach ( @args ) {
        if ( $_ eq "GLOBAL" ) {
            push @{$self->{_with}}, '(function(){return this;}).call(null)';
        }
        else {
            my $ns = $self->$register_ns($_);
            push @{$self->{_with}}, $ns;
        }
    }
};

*{__PACKAGE__.'::@namespace'} = sub : method {
    my ESModPP $self = shift;
    return $self->write($_[1])  unless $self->active;
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
    return $self->write($_[1])  unless $self->active;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        croak "Invalid identifier: `$_'"  unless is_identifier $_;
        if ( $target eq "GLOBAL" ) {
            push @{$self->{_global}}, $_;
            push @{$self->{_export}}, {namespace=>'', name=>$_};
        }
        else {
            push @{$self->{_shared}}, "$target.$_";
            push @{$self->{_export}}, {namespace=>$target, name=>$_};
        }
    }
};

*{__PACKAGE__.'::@shared'} = sub : method {
    my ESModPP $self = shift;
    return $self->write($_[1])  unless $self->active;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        croak "Invalid identifier: `$_'"  unless is_identifier $_;
        if ( $target eq "GLOBAL" ) {
            push @{$self->{_global}}, $_;
        }
        else {
            push @{$self->{_shared}}, "$target.$_";
        }
    }
};

*{__PACKAGE__.'::@include'} = sub : method {
    my ESModPP $self = shift;
    return $self->write($_[1])  unless $self->active;
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
