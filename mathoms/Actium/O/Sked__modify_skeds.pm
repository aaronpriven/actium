# Removed from Actium::O::Sked.pm

### METHODS THAT ALTER SKEDS

# This is commented out because it is only used in Headways,
# and alters the existing sked object, which I don't want to do

#sub divide_sked {
#    my $self = shift;
#
#    my @lines = $self->lines();
#
#    my %linegroup_of;
#    foreach (@lines) {
#        $linegroup_of{$_} = ( $LINES_TO_COMBINE{$_} || $_ );
#
#        #        $linegroup_of{$_} = ( $_ );
#    }
#
#    my %linegroups;
#    $linegroups{$_} = 1 foreach ( values %linegroup_of );
#    my @linegroups = keys %linegroups;
#
#    if ( scalar(@linegroups) == 1 ) {  # there's just one linegroup, return self
#        $self->set_linegroup( $lines[0] );
#
#        $self->delete_blank_columns;
#
#        # override Scheduling's linegroup with the first line
#        return $self;
#    }
#
#    # More than one linegroup! Split apart
#
#    my ( %trips_of, @newskeds );
#
#    # collect trips for each one in %trips_of
#    foreach my $trip ( $self->trips ) {
#        my $linegroup = $linegroup_of{ $trip->line };
#        push @{ $trips_of{$linegroup} }, $trip;
#    }
#
#    foreach my $linegroup (@linegroups) {
#
#        my %value_of;
#
#        # collect all other attribute values in %values_of
#        # This is a really primitive clone routine and might arguably
#        # be better replaced by something based on MooseX::Clone or some other
#        # "real" deep clone routine.
#
#        foreach my $attribute ( $self->meta->get_all_attributes ) {
#
#            # meta-objects! woohoo! screw you, Mouse!
#
#            my $attrname = $attribute->name;
#            next if $attrname eq 'trip_r' or $attrname eq 'linegroup';
#
#            my $value = $self->$attrname;
#            if ( ref($value) eq 'ARRAY' ) {
#                $value = [ @{$value} ];
#            }
#            elsif ( ref($value) eq 'HASH' ) {
#                $value = { %{$value} };
#            }    # purely speculative as there are no hash attributes right now
#
#            # use of "ref" rather than "reftype" is intentional here. We don't
#            # want to clone objects this way.
#
#            $value_of{$attrname} = $value;
#        }    ## <perltidy> end foreach my $attribute ( $self...)
#
#        my $newsked = Actium::O::Sked->new(
#            trip_r    => $trips_of{$linegroup},
#            linegroup => $linegroup,
#            %value_of,
#        );
#
#        $newsked->delete_blank_columns;
#
#        push @newskeds, $newsked;
#
#    }    ## <perltidy> end foreach my $linegroup (@linegroups)
#
#    return @newskeds;
#
#}    ## <perltidy> end sub divide_sked
