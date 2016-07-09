package Actium::Cmd::HeadwayTimes 0.011;

# This is intended to accept a tab-delimited text file and then display the
# minutes between times in the list.

use Actium::Preamble;

use Actium::Time qw(timenum);

###########################################
## COMMAND
###########################################

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium.pl headwaytimes filename.txt -- show the headway between times on the 
schedule

HELP

}

sub START {

    my $class  = shift;
    my $env = shift;
    my @argv = $env->argv;

  FILE:
    foreach my $filename (@argv) {
        open my $in, '<', $filename;

        say "---\n$filename\n---" unless @argv == 1;

        my $prev;
      LINE:
        while ( my $line = readline($in) ) {
            chomp($line);

            if ( not defined $prev ) {
                $prev = $line;
                say $line;
                next LINE;
            }

            my @prevtimes = timenum( split( "\t", $prev ) );
            my @times     = timenum( split( "\t", $line ) );

            my $numfields = u::min( $#prevtimes, $#times );

            my @headways;

          FIELD:
            for my $i ( 0 .. $numfields ) {
                my $prevtime = $prevtimes[$i];
                my $time     = $times[$i];

                if ( not defined $prevtime or not defined $time ) {
                    push @headways, undef;
                    next FIELD;
                }
                
                my $headway = ($time - $prevtime);
                
                $headway = $EMPTY_STR if $headway == 0;
                push @headways, $headway;

            }

            if ( u::any {defined} @headways ) {
                say u::jointab(@headways);
            }

            say $line;
            
            $prev = $line;

        } ## tidy end: LINE: while ( my $line = readline...)

    } ## tidy end: FILE: foreach my $filename (@argv)
} ## tidy end: sub START

1;

__END__
# TODO: Add POD
