#!/ActivePerl/bin/perl

use 5.010;

use strict;
use warnings;

my $dump = 0;
my $divider = '  ';

if ( defined $ARGV[0] and $ARGV[0] eq '-d' ) {
    $dump = 1;
    shift @ARGV;
}

if ( defined $ARGV[0] and $ARGV[0] eq '-t' ) {
    $divider = "\t";
    shift @ARGV;
}


my $simplefile = '/volumes/bireme/actium/db/current/SimpleStops.tab';

open my $in, '<', $simplefile
  or die "Can't open $simplefile";

my ( %of_phoneid, %of_stopid );

    use constant {
        PHONEID => 0,
        STOPID  => 1,
        DESC    => 2,
        LAT     => 3,
        LONG    => 4,
        ACTIVE  => 5
    };


{
    local $/ = "\r";    # FileMaker exports CRs

    while (<$in>) {

        chomp;
        next unless $_;
        my @fields  = split(/\t/);
        my $stopid  = $fields[STOPID];
        my $phoneid = $fields[PHONEID];
        $of_phoneid{$phoneid} = \@fields;
        $of_stopid{$stopid}   = \@fields;
    }

    close $in
      or die "Can't close $simplefile";
}

#binmode STDOUT, ":utf8";

if (@ARGV) {
    foreach (@ARGV) {
        use_argument($_);
    }
}
else {

    say 'Enter a stop ID, phone ID, or pattern to match.';
    say 'Enter a blank line to quit.';

    require Term::ReadLine;

    my $term = Term::ReadLine->new('st.pl');
    $term->ornaments(1);
    my $prompt = "st.pl >";
    while ( defined( $_ = $term->readline($prompt) ) ) {
        last if ( not $_ );
        use_argument($_);
        #$term->addhistory($_);
        say '';
    }

    #prompt();
    #while (<>) {
    #chomp;
    #say "[[$_]]";
    #last unless $_;
    #use_argument($_);
    #   prompt();

    #}
    say "Exiting.";
} ## tidy end: else [ if (@ARGV) ]

sub use_argument {
    local $_ = shift;

    if (/\A\d{5}\z/) {
        display( $of_phoneid{$_} );
        return;
    }

    if (/\A\d{6}\z/) {
        display( $of_stopid{"0$_"} );
        return;
    }

    if (/\A\d{7,8}\z/) {
        display( $of_stopid{"$_"} );
        return;
    }

    #if ($dump) {
    #        say "0||||";
    #} else {
    #warn "Unknown id type: $_\n";
    foreach my $fields_r ( values %of_stopid ) {

        my $desc = $fields_r->[DESC];

        s{/}{.*}g; 
        # slash is easier to type, doesn't need to be quoted,
        # not a regexp char normally
        display($fields_r) if $desc =~ m{$_}i;

    }

    #}

} ## tidy end: sub use_argument

sub display {

    my $fields_r = shift;
    
    if ( ref($fields_r) ne 'ARRAY' ) {
        if ($dump) {
            say "0||||";
        }
        else {
            say "Unknown id $_";
        }
        return;
    }
    
    my $active = (defined $fields_r->[ACTIVE] and
                 $fields_r->[ACTIVE] eq 'Yes');
    
    if ($dump) {
        say( join( q{|}, @{$fields_r} ) );

    }
    else {
        print( $fields_r->[PHONEID], $divider, $fields_r->[STOPID], $divider );
        say( $active ? '' : "*" , $fields_r->[DESC]);
    }

} ## tidy end: sub display
