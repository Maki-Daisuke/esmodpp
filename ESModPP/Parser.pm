package JSModPP;
our $VERSION = 0.0.1;

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



1;