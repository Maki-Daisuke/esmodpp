package ESModPP::Parser;
our $VERSION = 0.9.1;

use utf8;
use strict;
no strict 'refs';
no warnings 'uninitialized';

use Carp;

use Exporter;
use base qw/Exporter/;
our @EXPORT_OK   = qw/is_identifier parse_namespace/;
our %EXPORT_TAGS = (all => \@EXPORT_OK);


use fields qw/_warning _buffer/;

my $can = sub {
    my ($self, $method) = @_;
    $self->can($method) || $self->can("AUTOLOAD");
};

sub new {
    my $class = shift;
    $class = ref $class || $class;
    my ESModPP::Parser $self = fields::new($class);
    $self->{_buffer}  = "";
    $self->{_warning} = 1;
    $self;
}

sub warning {
    my ESModPP::Parser $self = shift;
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
    (my ESModPP::Parser $self, my $chunk) = @_;
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
            carp "Warning: an `instruction-like' line is ignored (probably, unmatched quotation?): $_"  if $self->{_warning};
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
    local *FILE;
    open FILE, $file  or  return;
    my $self = $class->new;
    read FILE, my $text, (stat FILE)[7];
    close FILE;
    $self->chunk($text);
    $self->eof;
}



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
    foreach ( split /[$white]*\.[$white]*/o ) {
        return unless is_identifier $_;
        push @id, $_;
    }
    return unless @id;
    @id;
}



1;
