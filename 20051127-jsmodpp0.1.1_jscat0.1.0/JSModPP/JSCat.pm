package JSModPP::JSCat;
our $VERSION = 0.1.0;

use Carp;
use File::Spec::Functions qw/catfile/;
use JSModPP::Basic;

use base qw/JSModPP::Basic/;
use fields qw/_require/;


sub new {
    my $class = shift;
    my JSModPP::JSCat $self = $class->SUPER::new;
    $self->{_require} = [];
    $self;
}


sub require {
    my JSModPP::JSCat $self = shift;
    @{$self->{_require}};
}


*{__PACKAGE__.'::@require'} = sub {
    my JSModPP::JSCat $self = shift;
    my @args = @{shift()};
    croak '@require requires one or more arguments.'  unless @args;
    push @{$self->{_require}}, map{ catfile(split/\./) . ".js" } @args;
};



1;
