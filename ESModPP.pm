package ESModPP;
our $VERSION = 0.10.1;

use strict;
no strict 'refs';
no warnings 'uninitialized';

use ESModPP::Parser;
use Exporter;
use Carp;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

use base qw/Exporter ESModPP::Parser/;
our @EXPORT_OK   = qw/is_identifier parse_namespace version_cmp/;
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
    _require
    _extend
};

sub new : method {
    my $class = shift;
    my ESModPP $self = $class->SUPER::new;
    $self->{_buffer}    = "";
    $self->{_esmodpp}   = undef;     # true | false (undef means no @esmodpp directive has appeared.)
    $self->{_version}   = undef;     # /VERSION/ | undef (undef means no @version directive has appeared)
    $self->{_target}    = "GLOBAL";  # /NAMESPACE/
    $self->{_namespace} = {};        # {/NAMESPACE/ => [/IDENTIFIER/]}
    $self->{_with}      = [];        # [/NAMESPACE/]
    $self->{_export}    = {};        # {/IDENTIFIER/ => /NAMESPACE/}
    $self->{_shared}    = [];        # [{"namespace"=>/NAMESPACE/, "name"=>/IDENTIFIER/}]
    $self->{_require}   = {};        # {/NAMESPACE/ => /VERSPEC/}
    $self->{_extend}    = {};        # {/NAMESPACE/ => /VERSPEC/}
    $self;
}


my $re_version = qr{\d+(?:\.\d+)*};
my $re_verspec = qr{=$re_version|$re_version\+?};


my $croak = sub : method {
    my ESModPP $self = shift;
    croak @_, " at line ", $self->lineno;
};

my $register_ns = sub : method {
    my ESModPP $self = shift;
    my $ns = shift;
    my @id = parse_namespace($ns)  or $self->$croak("Invalid namespace: `$ns'");
    $ns = join ".", @id;
    $self->{_namespace}{$ns} = \@id;
    $ns;
};

my $duplicate_check = sub : method {
    my ESModPP $self = shift;
    my ($module, $version) = @_;
    $module = join ".", parse_namespace($module)    or $self->$croak("Invalid module name: `$module'");
    if ( length $version ) {
        $self->$croak("Invalid version-specifier: `$version'")  unless $version =~ /^$re_verspec$/o;
        if ( defined $self->{_require}{$module}  and  $self->{_require}{$module} ne $version ) {  # version of `undef' does not restrict module version.
            $self->$croak("`$module' is already required with version $self->{_require}{$module}, but required again with version $version.");
        }
        if ( defined $self->{_extend}{$module}  and  $self->{_extend}{$module} ne $version ) {
            $self->$croak("`$module' is already required with version $self->{_extend}{$module}, but required again with version $version.");
        }
    }
    ($module, $version);
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
    my ESModPP $self = shift;
    $self->{_buffer} .= join "", @_;
}

sub result : method {
    my ESModPP $self = shift;
    return $self->{_buffer}  unless defined $self->{_esmodpp};
    my $buf = "(function(){\n";  # Top-level closure, which ensures that this-value refers the Global Object.
    foreach ( values %{$self->{_namespace}} ) {
        my @names = @$_;
        my $name = "this";
        while ( @names ) {
            $name .= "." . shift @names;
            $buf .= "    if ( !$name || (typeof $name != 'object' && typeof $name != 'function') ) $name = new Object();\n";
        }
    }
    foreach ( @{$self->{_shared}} ) {
        local $_ = $_->{namespace} eq "GLOBAL" ? $_->{name} : "$_->{namespace}.$_->{name}";
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
                @{[ join ", ", map{"$_: $_"} keys %{$self->{_export}} ]}
            };
        }();
    };
    $buf .= "}\n" x @{$self->{_with}};
    $buf .= "}.call(null) ) {\n";
    while ( my ($name, $ns) = each %{$self->{_export}} ) {
        $ns = $ns eq "GLOBAL" ? $name : "$ns.$name";
        $buf .= "    this.$ns = $name;\n";
    }
    $buf .= "}\n";     # End of with
    $buf .= "}).call(null);\n";  # The end of the top-level closure.
    $buf;
}

sub require : method {
    my ESModPP $self = shift;
    return { %{$self->{_require}} };
}

sub extend : method {
    my ESModPP $self = shift;
    return { %{$self->{_extend}} };
}


sub directive : method {
    my ESModPP $self = shift;
    if ( $self->{_esmodpp}  or  $_[0] eq '@esmodpp' ) {
        $self->SUPER::directive(@_);
    } else {
        $self->write($_[2]);
    }
}

sub text : method {
    (my ESModPP $self, my $text) = @_;
    $self->write($text);
}

*{__PACKAGE__.'::@esmodpp'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    my $text = shift;
    if ( @args ) {
        $self->$croak('@esmodpp takes at most one argument')                                 unless @args == 1;
        local $_ = shift @args;
        if ( /^off$/i ) {
            if ( $self->{_esmodpp} ) { $self->{_esmodpp} = "" }
            else                     { $self->write($text)    }
            return;
        }
        $self->$croak("Invalid version string: `$_'")                                        unless /^$re_version$/o;
        $self->$croak(sprintf "ESModPP %s is required, but this is only %vd", $_, $VERSION)  if version_cmp($_, $VERSION) > 0;
    }
    $self->{_esmodpp} = 1;
};

*{__PACKAGE__.'::@version'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@version takes just one argument')  unless @args == 1;
    local $_ = shift @args;
    $self->$croak("Invalid version string: `$_'")      unless /^$re_version$/o;
    $self->$croak('@version appears more than once')   if defined $self->{_version};
    $self->{_version} = $_;
};

*{__PACKAGE__.'::@use-namespace'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@use-namespace takes just one argument')  unless @args == 1;
    my $ns = $args[0] eq "GLOBAL" ? "GLOBAL" : $self->$register_ns($args[0]);
    $self->{_target} = $ns;
    $self->write("NAMESPACE = '$ns';\n");
};

*{__PACKAGE__.'::@with-namespace'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@with-namespace requires one or more arguments')  unless @args;
    foreach ( @args ) {
        if ( $_ eq "GLOBAL" ) {
            push @{$self->{_with}}, 'this';
        } else {
            my $ns = $self->$register_ns($_);
            push @{$self->{_with}}, $ns;
        }
    }
};

*{__PACKAGE__.'::@namespace'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    my $text = shift;
    $self->$croak('@namespace takes just one argument.')  unless @args == 1;
    my $use  = '@use-namespace';
    my $with = '@with-namespace';
    $self->$use(\@args, $text);
    $self->$with(\@args, $text);
};

*{__PACKAGE__.'::@export'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        $self->$croak("Invalid identifier: `$_'")  unless is_identifier($_);
        $self->$croak("Redundantly exported symbol: `$_'")  if exists ${$self->{_export}}{$_};
        push @{$self->{_shared}}, {namespace=>$target, name=>$_};
        ${$self->{_export}}{$_} = $target;
    }
};

*{__PACKAGE__.'::@shared'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        $self->$croak("Invalid identifier: `$_'")  unless is_identifier($_);
        push @{$self->{_shared}}, {namespace=>$target, name=>$_};
    }
};

*{__PACKAGE__.'::@include'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@include requires one or more arguments.')  unless @args;
    foreach my $file ( @args ) {
        local *FILE;
        OPEN: unless ( open FILE, $file ) {
            unless ( file_name_is_absolute $file ) {
                foreach ( split /;/, $ENV{ES_INCLUDE} ) {
                    open(FILE, catfile $_, $file) and last OPEN;
                }
            };
            $self->$croak("Can't open included file `$file': $!");
        }
        read FILE, my $text, (stat FILE)[7];
        close FILE;
        $self->unread($text);
    }
};

*{__PACKAGE__.'::@require'} = sub {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@require requires at least one argument.')  unless @args;
    $self->$croak('@require takes at most two arguments.')     if @args > 2;
    my ($module, $version) = $self->$duplicate_check(@args);
    $self->{_require}{$module} = $version;
};

*{__PACKAGE__.'::@extend'} = sub {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@extend requires at least one argument.')  unless @args;
    $self->$croak('@extend takes at most two arguments.')     if @args > 2;
    my ($module, $version) = $self->$duplicate_check(@args);
    $self->{_extend}{$module} = $version;
};



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
    /^$Identifier$/o  and  not exists $reserved{$_};
}

sub parse_namespace ($) {
    local $_ = shift;
    my @id;
    foreach ( split /\./ ) {
        return unless is_identifier $_;
        push @id, $_;
    }
    return unless @id;
    @id;
}


sub split_version {
    local $_ = shift;
    $_ = sprintf "%vd", $_  unless /^$re_version$/o;
    split /\./;
}

sub version_cmp {
    my @l = split_version shift;
    my @r = split_version shift;
    while ( @l || @r ) {
        my $cmp = shift @l <=> shift @r;
        return $cmp  if $cmp;
    }
    return 0;
}


1;
