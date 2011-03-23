

1;

__END__


{
    my %pats_of_stop;

    sub set_pats_of_stop {
        my ( $stop_ident, $routedir, $pat_ident, $patinfo ) = @_;
        $pats_of_stop{$stop_ident}{$routedir}{$pat_ident} = $patinfo;
        return;
    }

    sub pat_idents_of {
        my ( $stop, $routedir ) = @_;
        return keys %{ $pats_of_stop{$stop}{$routedir} };

    }

    sub keys_pats_of_stop {
        return keys(%pats_of_stop);
    }

    sub routedirs_of_stop {
        my $routedir = shift;
        return keys %{ $pats_of_stop{$routedir} };
    }

    sub delete_identifiers {
        # delete identifiers in lists for identical place patterns

        my ( $routedir, $replacement_rdi, @pat_rdis ) = @_;
        my ( $route, $dir ) = sk($routedir);

        my $replacement_ident = $replacement_rdi;
        $replacement_ident =~ s/.*$KEY_SEPARATOR//sx;

        # %placelist_of, %stops_of_pat, %pats_of_stop
        foreach my $pat_rdi (@pat_rdis) {
            my $pat_ident = $pat_rdi;
            $pat_ident =~ s/.*$KEY_SEPARATOR//sx;
            my @stops = @{ $stops_of_pat{$pat_rdi} };
            delete $placelist_of{$pat_rdi};
            delete $stops_of_pat{$pat_rdi};
            foreach my $stop_ident (@stops) {

                if (scalar
                    keys %{ $pats_of_stop{$stop_ident}{$routedir} } == 1 )
                {
                    $pats_of_stop{$stop_ident}{$routedir}{$replacement_ident}
                      = $pats_of_stop{$stop_ident}{$routedir}{$pat_ident};
                }

                delete $pats_of_stop{$stop_ident}{$routedir}{$pat_ident};
                $routes_of_stop{$stop_ident}{$route}--;
            }

        } ## tidy end: foreach my $pat_rdi (@pat_rdis)

        return;

    } ## tidy end: sub delete_identifiers

    sub delete_last_stops {

        emit 'Deleting final stops';

        foreach my $stop ( keys %pats_of_stop ) {
            foreach my $routedir ( keys %{ $pats_of_stop{$stop} } ) {
                my ( $route, $dir ) = sk($routedir);
                foreach
                  my $pat_ident ( keys %{ $pats_of_stop{$stop}{$routedir} } )
                {

                    next
                      unless exists $pats_of_stop{$stop}{$routedir}{$pat_ident}
                          {Last};

                    next if $routes_of_stop{$stop}{$route} == 1;

                    delete $pats_of_stop{$stop}{$routedir}{$pat_ident};
                    if ( not %{ $pats_of_stop{$stop}{$routedir} } ) {
                        delete $pats_of_stop{$stop}{$routedir};
                    }
                    $routes_of_stop{$stop}{$route}--;

                }
            } ## tidy end: foreach my $routedir ( keys...)
        } ## tidy end: foreach my $stop ( keys %pats_of_stop)
        emit_done;

        return;

    } ## tidy end: sub delete_last_stops

}