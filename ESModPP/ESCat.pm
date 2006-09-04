package ESModPP::ESCat;
our $VERSION = 0.9.2;

use Carp;
use File::Spec::Functions qw/catfile/;
use ESModPP qw/parse_namespace/;

use constant MODULE_EXT => ".js";

use base qw/ESModPP/;
use fields qw/_require/;

sub new {
    my $class = shift;
    my ESModPP::ESCat $self = $class->SUPER::new;
    $self->{_require} = {};
    $self;
}


sub require {
    my ESModPP::ESCat $self = shift;
    return { %{$self->{_require}} };
}


*{__PACKAGE__.'::@require'} = sub {
    my ESModPP::ESCat $self = shift;
    my @args = @{shift()};
    croak '@require requires at least one argument.'  unless @args;
    croak '@require takes at most two arguments.'     if @args > 2;
    my @names = parse_namespace $args[0]              or croak "Invalid module name: `$args[0]'";
    my $version;
    if ( @args == 2 ) {
        local $_ = $args[1];
        croak "Invalid version string: `$_'"  unless /^\d+(?>\.\d+)*$/;
        $version = $_;
    }
    $self->{_require}{ catfile(@names) . MODULE_EXT } = $version;
};



1;
