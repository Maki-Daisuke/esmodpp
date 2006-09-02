package JSModPP;
our $VERSION = 0.0;

use utf8;
use Carp;

use fields qw/_warning _buffer _source/;

my $can = sub {
    my ($self, $method) = @_;
    $self->can($method) || $self->can("AUTOLOAD");
};

sub new {
    my $class = shift;
    $class = ref $class || $class;
    my JSModPP $self = fields::new($class);
    $self->{_buffer}  = "";
    $self->{_source}  = "";
    $self->{_warning} = 1;
    $self;
}

sub source {
    my JSModPP $self = shift;
    $self->{_source};
}

sub warning {
    my JSModPP $self = shift;
    $self->{_warning} = shift  if @_;
    $self->{_warning};
}


# This is called when text sequence which is not a preprocessor-instruction is found.
sub text {
    my $class = ref shift;
    croak "${class}::text is not implemented";
}

# This is called when eof method is called.
sub result {
    my $class = ref shift;
    croak "${class}::result is not implemented";
}


my $terminator    = '\x{000A}\x{000D}\x{2028}\x{2029}';
my $re_terminator = qr{[$terminator]};
my $white         = '\t\x{000B}\f \x{00A0}\p{IsZs}';
my $instruction   = qr{^[$white]*//(\@[A-Za-z0-9_-]+)};
my $literal       = qr{([^$terminator$white'"][^$terminator$white]*)};
my $single_quoted = qr{'([^$terminator$white']*(?:''[^$terminator$white']*)*)'};
my $double_quoted = qr{"([^$terminator$white"]*(?:""[^$terminator$white"]*)*)"};
my $argument      = qr{$literal|$single_quoted|$double_quoted};

sub chunk {
    (my JSModPP $self, my $chunk) = @_;
    $self->{_source} .= $chunk;
    my @lines = split /$re_terminator/, $chunk, -1;
    return 1  unless @lines;
    $lines[0] = $self->{_buffer} . $lines[0];
    if ( $lines[-1] ) {
        $self->{_buffer} = pop @lines;
    }
    else {
        pop @lines;
        $self->{_buffer} = "";
    }
    foreach ( @lines ) {
        unless ( /$instruction/gco ) {
            $self->text([], "$_\n");
            next;
        }
        my $name = $1;
        $self->text([], "$_\n"), next  unless $self->$can($name);
        my @args = ();
        while ( /\G[$white]+$argument/gco ) {
             my $value  = $1;
            (my $single = $2) =~ s/''/'/g;
            (my $double = $3) =~ s/""/"/g;
            push @args, "$value$single$double";
        }
        unless ( /\G[$white]*$/gco ) {
            carp "Warning: `instruction-like' line is ignored (probably, unmatched quotation?): $_"  if $self->{_warning};
            $self->text([], "$_\n");
            next;
        }
        $self->$name([@args], "$_\n");
    }
    return 1;
}

sub eof {
    my $self = shift;
    $self->chunk("\n");
    $self->result;
}


sub preprocess {
    my ($class, $text) = @_;
    $class = ref $class || $class;
    my $self = $class->new;
    $self->chunk($text);
    $self->eof;
}

sub handle {
    my ($class, $fh) = @_;
    $class = ref $class || $class;
    my $self = $class->new;
    $self->chunk($_)  while <$fh>;
    $self->eof;
}

sub file {
    my ($class, $file) = @_;
    $class = ref $class || $class;
    my $self = $class->new;
    local *FILE;
    open FILE, $file  or  return;
    read FILE, my $text, (stat FILE)[7];
    close FILE;
    $self->chunk($text);
    $self->eof;
}



package JSModPP::Basic;
our $VERSION = 0.0;

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
    foreach ( split /[\white]*\.[\white]*/ ) {
        die "Invalid identifier: `$_'"  unless is_identifier $_;
        push @id, $_;
    }
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
    _require
};

sub new {
    my $class = shift;
    my JSModPP::Basic $self = $class->SUPER::new;
    $self->{_buffer}    = "";
    $self->{_jsmodpp}   = undef;
    $self->{_target}    = ["window"];
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

sub requires {
    my JSModPP::Basic $self = shift;
    @{$self->{_require}};
}

sub result {
    my JSModPP::Basic $self = shift;
    return $self->source  unless $self->{_jsmodpp};
    my $buf = "";
    foreach ( @{$self->{_namespace}} ) {
        my @names = @$_;
        my $name = "window";
        while ( @names ) {
            $name .= "." . shift @names;
            $buf .= "if ( !$name || typeof $name != 'object' ) $name = new Object();\n";
        }
    }
    foreach ( @{$self->{_shared}} ) {
        $buf .= "if ( typeof $_ === 'undefined' ) $_ = undefined;\n";
    }
    $buf .= "+function(){\n";
        foreach ( reverse @{$self->{_with}} ) {
            $buf .= "with ( $_ ) {\n";
        }
            $buf .= qq{
                var \$export = function () {
                    @{[ $self->{_buffer} ]}
                    return {
                        @{[ join ", ", map{"$_->{name}: $_->{name}"} @{$self->{_export}} ]}
                    };
                }();
            };
        $buf .= "}\n" x @{$self->{_with}};
        foreach ( @{$self->{_export}} ) {
            my ($ns, $name) = ($_->{namespace}, $_->{name});
            $buf .= "$ns.$name = \$export.$name;\n";
        }
    $buf .= "}();\n";
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
        die "Version $args[0] is required, but this is only $VERSION"  if $args[0] > $VERSION;
    }
    $self->{_jsmodpp} = 1;
};

*{__PACKAGE__.'::@use-namespace'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    die '@use-namespace takes just one argument.'  unless @args == 1;
    my $ns = parse_namespace $args[0];
    push @{$self->{_namespace}}, $ns;
    $self->{_target} = join ".", @$ns;
};

*{__PACKAGE__.'::@export'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        die "Invalid identifier: `$_'"  unless is_identifier $_;
        push @{$self->{_shared}}, "$target.$_";
        push @{$self->{_export}}, {namespace=>$target, name=>$_};
    }
};

*{__PACKAGE__.'::@shared'} = sub {
    my JSModPP::Basic $self = shift;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        die "Invalid identifier: `$_'"  unless is_identifier $_;
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
    die '@namespace takes just one argument.'  unless @args == 1;
    my $ns = parse_namespace $args[0];
    push @{$self->{_namespace}}, $ns;
    $ns = join ".", @$ns;
    push @{$self->{_with}}, $ns;
    $self->{_target} = $ns;
};

*{__PACKAGE__.'::@include'} = sub {
    my $self = shift;
    my @args = @{shift()};
    die '@include requires one or more arguments.'  unless @args;
    foreach my $file ( @args ) {
        local *FILE;
        OPEN: unless ( open FILE, $file ) {
            not file_name_is_absolute $file and do{
                foreach ( split /;/, $ENV{JSMODPP_INCLUDE} ) {
                    open(FILE, catfile $_, $file) and last OPEN;
                }
            };
            die "Can't read file: $file";
        }
        read FILE, my $text, (stat FILE)[7];
        close FILE;
        $self->write($text);
    }
};

*{__PACKAGE__.'::@require'} = sub {
    my $self = shift;
    my @args = @{shift()};
    die '@require requires one or more arguments.'  unless @args;
    push @{$self->{_require}}, @args;
};


1;
