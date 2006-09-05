package ESModPP::Parser;
our $VERSION = 0.9.2;

use utf8;
use strict;
no strict 'refs';
no warnings 'uninitialized';

use Carp;


use fields qw/_buffer _lineno _warning/;

sub new {
    my $class = shift;
    $class = ref $class || $class;
    my ESModPP::Parser $self = fields::new($class);
    $self->{_buffer}  = "\n";
    $self->{_lineno}  = 0;
    $self->{_warning} = 1;
    $self;
}

sub warning : method {
    my ESModPP::Parser $self = shift;
    $self->{_warning} = shift  if @_;
    $self->{_warning};
}

sub lineno : method {
    my ESModPP::Parser $self = shift;
    $self->{_lineno};
}

my $can = sub : method {
    my ($self, $method) = @_;
    $self->can($method) || $self->can("AUTOLOAD");
};

# This is called when text sequence which is not a preprocessor-directive is found.
sub directive : method {
    my ESModPP::Parser $self = shift;
    my ($name, $args, $line) = @_;
    if ( $self->$can($name) ) {
        $self->$name($args, $line);
    } else {
        $self->text($line);
    }
}

# This is called when text sequence which is not a preprocessor-directive is found.
sub text : method {
    my $class = ref shift;
    croak "${class}::text is not implemented";
}

# This is called when eof method is called.
sub result : method {
    my $class = ref shift;
    croak "${class}::result is not implemented";
}


my $terminator    = '\x{000A}\x{000D}\x{2028}\x{2029}';
my $line          = qr{[^$terminator]*[$terminator]};
my $white         = '\t\x{000B}\f \x{00A0}\p{IsZs}';
my $directive     = qr{(//\@[A-Za-z0-9_-]+)([^$terminator]*)};
my $literal       = qr{([^$terminator$white'"][^$terminator$white]*)};
my $single_quoted = qr{'([^$terminator$white']*(?:''[^$terminator$white']*)*)'};
my $double_quoted = qr{"([^$terminator$white"]*(?:""[^$terminator$white"]*)*)"};
my $argument      = qr{$literal|$single_quoted|$double_quoted};


sub chunk : method {
    (my ESModPP::Parser $self, my $chunk) = @_;
    $self->{_buffer} .= $chunk;
    my $start_line = 0;
    while ( $self->{_buffer} =~ /[$terminator]+/gco ) {
        $start_line = $+[0];
        if ( $self->{_buffer} =~ /\G[$white]*$directive/gco ) {
            my ($name, $args) = (substr($1, 2), $2);
            my $before = substr $self->{_buffer}, 0, $-[0];
            $self->{_buffer} = substr $self->{_buffer}, $+[0];
            $start_line = 0;
            $self->{_lineno}++  while $before =~ /\x0D\x0A|[$terminator]/gc;
            $self->text($before);
            my @args = ();
            while ( $args =~ /\G[$white]+$argument/gco ) {
                 my $literal = $1;
                (my $single  = $2) =~ s/''/'/g;
                (my $double  = $3) =~ s/""/"/g;
                push @args, "$literal$single$double";
            }
            unless ( $args =~ /\G[$white]*$/gco ) {
                carp "Warning: `directive-like' line is ignored (probably, unmatched quotation?) at ", $self->lineno, ": //$name$args"  if $self->{_warning};
                $self->text("//$name$args");
                next;
            }
            $self->directive($name, \@args, "//$name$args");
        }
    }
    if ( $start_line ) {
        my $before = substr $self->{_buffer}, 0, $start_line-1, "";
        $self->{_lineno}++  while $before =~ /\x0D\x0A|[$terminator]/gc;
        $self->text($before);
    }
    return 1;
}

sub unread : method {
    my ESModPP::Parser $self = shift;
    $self->{_buffer} = join("", @_) . $self->{_buffer};
}

sub eof : method {
    my ESModPP::Parser $self = shift;
    $self->text($self->{_buffer});
    $self->{_buffer} = "\n";
    $self->{_lineno} = 0;
    $self->result;
}


sub string : method {
    my ($class, $text) = @_;
    $class = ref $class || $class;
    my $self = $class->new;
    $self->chunk($text);
    $self->eof;
}

sub handle : method {
    my ($class, $fh) = @_;
    $class = ref $class || $class;
    my $self = $class->new;
    $self->chunk($_)  while <$fh>;
    $self->eof;
}

sub file : method {
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
