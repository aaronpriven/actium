package Octium::Cmd::Frequency 0.011;

use Actium;
use Octium;
use Octium::Frequency;

use Array::2D;
use Actium::Time;

sub HELP {
    say 'Determines the frequency of times.';
    return;
}

sub OPTIONS {

    return (
        {   spec        => 'column=i',
            description => 'Column that contains the times (starting with 1). '
              . 'Default is the first column.',
        },
        {   spec        => 'skiplines=i',
            description =>,
            'Lines to skip from the beginning. Default is 0.', fallback => 0
        },
        { spec => 'breaks=s', 'Breaks in the frequency calculation' },
    );
}

sub START {

    my $class = shift;
    my $env   = shift;

    my @argv = $env->argv;

    my $input_file = shift @argv;
    my $column     = $env->option('column');
    my $skiplines  = $env->option('skiplines');
    my $breaks     = $env->option('breaks');

    my $aoa = Array::2D->new_from_file($input_file);

    my @times = $aoa->col( $column - 1 );
    if ($skiplines) {
        @times = @times[ $skiplines .. $#times ];
    }

    my @orig_timenums
      = grep {defined} ( map { Actium::Time->from_str($_)->timenum } @times );

    my $first = Actium::Time::->from_num( $orig_timenums[0] )->ap;

    my @timenums = Octium::Frequency::adjust_timenums(@orig_timenums);
    my $final    = Actium::Time::->from_num( $timenums[-1] )->ap;

    ( \my @sets, \my @breaktimes )
      = Octium::Frequency::break_sets( $breaks, \@timenums );

    my @freqs;

    foreach my $idx ( 0 .. $#sets ) {
        my $set       = $sets[$idx];
        my $breaktime = $breaktimes[$idx];
        $breaktime = defined($breaktime) ? " starting $breaktime" : '';
        my ( $freq_display, $freq ) = Octium::Frequency::frequency($set);
        say "$freq_display\n===";
        push @freqs, "Frequency$breaktime: $freq";
    }

    say "First: $first";
    say $_ foreach @freqs;
    say "Last: $final";

    return;

}    ## tidy end: sub START

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

