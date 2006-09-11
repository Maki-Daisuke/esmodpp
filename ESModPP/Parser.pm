package ESModPP::Parser;
our $VERSION = 0.10.0;

use utf8;
use strict;
no strict 'refs';
no warnings 'uninitialized';

use Carp;
use Symbol qw/qualify_to_ref/;


use fields qw/_buffer _lineno/;

sub new {
    my $class = shift;
    $class = ref $class || $class;
    my ESModPP::Parser $self = fields::new($class);
    $self->{_buffer}  = "\n";
    $self->{_lineno}  = 0;
    $self;
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
        $self->warning("directive line is found but ignored, since `$name' method is not defined (possibly typo?)");
        $self->text($line);
    }
}

# This is called when text sequence which is not a preprocessor-directive is found.
sub text : method {
    my $class = shift;
    $class = ref $class || $class;
    croak "${class}::text is not implemented";
}

# This is called when eof method is called.
sub result : method {
    my $class = shift;
    $class = ref $class || $class;
    croak "${class}::result is not implemented";
}

# This is called when issuing warning.
sub warning : method {
    my ESModPP::Parser $self = shift;
    print STDERR "WARNING: ", @_, " at line ", $self->lineno, "\n";
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
                $self->warning("`directive-like' line is ignored (probably, unmatched quotation?)");
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


sub handle : method {
    my ESModPP::Parser $self = shift;
    my $fh = shift;
    $fh = qualify_to_ref $fh, caller  unless ref $fh;
    $self->chunk($_)  while <$fh>;
}

sub file : method {
    my ESModPP::Parser $self = shift;
    my $file = shift;
    local *FILE;
    open FILE, $file  or  return;
    read FILE, my $text, (stat FILE)[7];
    $self->chunk($text);
}



1;
