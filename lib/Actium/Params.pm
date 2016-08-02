package Actium::Params 0.012;

use Actium::Preamble;

use Type::Params('validate');
use Types::Standard (qw(slurpy Dict Any Optional));

sub namedparams (\@+) {
    \my @p    = shift;
    \my %spec = shift;

    my %results;

    my %newspec;

    foreach my $key ( keys %spec ) {
        my $value = $spec{$key};
        if ( u::is_hashref($value) and scalar keys $value->%* == 0 ) {
            # more specifications
            \my %param_spec = $value;
            if ( exists $param_spec{dest} ) {
                croak "Parameter destination must be a reference"
                  unless u::is_ref( $param_spec{dest} );
                $results{$key} = $param_spec{dest};
            }
            if ( exists $param_spec{spec} ) {
                $param_spec{spec} = Optional[$param_spec{spec}]
                  if $param_spec{optional};
                $newspec{$key} = $param_spec{spec};
            }
            elsif ( $param_spec{optional} ) {
                $newspec{$key} = Optional[Any];
            }
        } ## tidy end: if ( u::is_hashref($value...))
        elsif ( u::is_ref($value) ) {
            $results{$key} = $value;
            $newspec{$key} = Any;
        }

    } ## tidy end: foreach my $key ( keys %spec)

  # have to munge the spec and send it to Type::Params::validate

} ## tidy end: sub namedparams (\@+)

1;
