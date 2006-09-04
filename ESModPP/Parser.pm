package ESModPP::Parser;
our $VERSION = 0.9.2;

use utf8;
use strict;
no strict 'refs';
no warnings 'uninitialized';

use Carp;


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


# This is called when text sequence which is not a preprocessor-directive is found.
sub directive {
    my ESModPP::Parser $self = shift;
    my ($name, $args, $line) = @_;
    if ( $self->$can($name) ) {
        $self->$name($args, $line);
    } else {
        $self->text($line);
    }
}

# This is called when text sequence which is not a preprocessor-directive is found.
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
my $line          = qr{[^$terminator]*[$terminator]};
my $white         = '\t\x{000B}\f \x{00A0}\p{IsZs}';
my $directive     = qr{^[$white]*//(\@[A-Za-z0-9_-]+)};
my $literal       = qr{([^$terminator$white'"][^$terminator$white]*)};
my $single_quoted = qr{'([^$terminator$white']*(?:''[^$terminator$white']*)*)'};
my $double_quoted = qr{"([^$terminator$white"]*(?:""[^$terminator$white"]*)*)"};
my $argument      = qr{$literal|$single_quoted|$double_quoted};

sub chunk {
    (my ESModPP::Parser $self, my $chunk) = @_;
    $chunk = $self->{_buffer} . $chunk;
    while ( $chunk =~ /\G($line)/gco ) {
        local $_ = $1;
        unless ( /$directive/gco ) {
            $self->text($_);
            next;
        }
        my $name = $1;
        my @args = ();
        while ( /\G[$white]+$argument/gco ) {
             my $value  = $1;
            (my $single = $2) =~ s/''/'/g;
            (my $double = $3) =~ s/""/"/g;
            push @args, "$value$single$double";
        }
        unless ( /\G[$white]*$/gco ) {
            carp "Warning: `directive-like' line is ignored (probably, unmatched quotation?): $_"  if $self->{_warning};
            $self->text($_);
            next;
        }
        $self->directive($name, \@args, $_);
    }
    $self->{_buffer} = substr $chunk, pos $chunk;
    return 1;
}

sub eof {
    my $self = shift;
    $self->chunk("\n");
    $self->result;
}


sub string {
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



1;
