#!/ActivePerl/bin/perl

@ARGV = qw(-s sp09) if $ENV{RUNNING_UNDER_AFFRUS};

# avl2stoplines-dir

# Another variant of avl2stoplines, this one lists directions as well as routes
# legacy stage 2

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

use 5.010;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ( $Bin, "$Bin/../bin" );

use Carp;
use POSIX ('ceil');

#use Fatal qw(open close);
use Storable();

use Actium::Util(qw<jt>);
use Actium::Sorting::Line (qw[sortbyline]);
use Actium::Constants;
use Actium::Union('ordered_union');

use List::Util ('max');
use List::MoreUtils ('any');

use Actium::DaysDirections (':all');

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2stoplines reads the data written by readavl and turns it into a 
list of stops with the lines served by that stop.
It is saved in the file "stoplines.txt" in the directory for that signup.
EOF

my $intro
  = 'avl2stoplines -- make a list of stops with lines served from AVL data';
  
use Actium::Options ('init_options');
use Actium::O::Folders::Signup;

init_options;


my $signup = Actium::O::Folders::Signup->new();
chdir $signup->path();

use Actium::Files::FileMaker_ODBC (qw[load_tables]);

my (@stops, %desc_of);

load_tables(
    requests => {
        Stops_Neue => {
            array        => \@stops,
            index_field => 'h_stp_511_id',
            fields => [ qw/h_stp_511_id c_description_full/ ],
        },
    }
);

foreach my $stop_row (@stops) {
     my $id = $stop_row->{h_stp_511_id};
     my $desc =  $stop_row->{c_description_full};
     $desc_of{$id} = $desc;
}


# retrieve data

my %pat;
my %stp;

{    # scoping

# the reason to do this is to release the %avldata structure, so Affrus
# (or, presumably, another IDE)
# doesn't have to display it when it's not being used. Of course it saves memory, too

my $avldata_r = $signup->retrieve('avl.storable');

    %pat = %{ $avldata_r->{PAT} };

    %stp = %{ $avldata_r->{STP} };

}

my (%disp_route_of);

my %code_of = (
    route  => \&route,
    rdir   => \&rdir,
    rcdir  => \&rcdir,
    r6dir  => \&r6dir,
    r6cdir => \&r6cdir,
);

my @opp = qw( EB WB NB SB CC CW A B);
my %opposite_of = ( @opp, reverse @opp );

my @code_order = qw/route rdir rcdir r6dir r6cdir/;

my %known_black_flags = (
    54883 => 'Broadway @ 38th, southbound, Oakland',
    55448 => '1125 Jackson, northbound, Albany',
    59567 => '20th at San Pablo, fs eastbound',
    54484 => 'Seminary @ Division 4',
    59055 => 'Seminary @ Division 4',
    56611 => 'MacArthur @ Coolidge, westbound',
50269 => 'Jackson St. & Ohlone, Albany, NS',
50239 => 'Chabot College',
50238 => 'Chabot College',
    
    
);

my %alameda_shuttle_flags = (
    50101 => 'Atlantic & Independence Plaza WB',
    53394 => 'Mariner Square & Willie Stargell NB',
    57750 => 'Webster @ Santa Clara SB',
    50243 => 'W. Midway @ Orion WB',
    55523 => 'Alameda Towne Center @ Borders EB (near Park)',
    52256 => 'whitehall @ willow EB',
    50399 => 'otis @ broadway wb',
    57367 => 'shoreline @ kitty hawk/willow wb',
    57793 => '8th & Portola NB',
    56668 => 'blanding @ broadway wb',
    55359 => 'broadway @ lincoln sb',
    51129 => 'Island Dr. @ Harbor Bay Landing (883 Island), SB',
    58377 => 'Mecartney Rd. @ Leydecker Park / Library, WB',
    51134 => 'High St. & Santa Clara Ave. SB',
    57727 => 'High St. & Encinal Ave. SB',
    56513 => 'High St. & Krusi Park / Calhoun, SB',
);

my %future_bsh_flags = (
    55771 => 'Broadway & Grand FS FS',
    59522 => 'Broadway & 25th NS NB',
    53353 => 'Broadway & Grand FS SB',
);

PAT:
foreach my $key ( keys %pat ) {

    next unless $pat{$key}{IsInService};

    my $route = $pat{$key}{Route};
    next if $route eq '399';

    next if $route =~ /BS[DNH]/;

    my $dir = dir_of_hasi ( $pat{$key}{DirectionValue} );

    #foreach my $tps_r ( @{$pat{$key}{TPS}}) {
    for my $tps_n ( 0 .. $#{ $pat{$key}{TPS} } ) {
        my $tps_r  = $pat{$key}{TPS}[$tps_n];
        my $stopid = $tps_r->{StopIdentifier};
        next unless $stopid =~ /^\d+$/msx;

        $dir .= "-LAST" if $tps_n == $#{ $pat{$key}{TPS} };

        foreach my $codekey ( keys %code_of ) {
            my $display = $code_of{$codekey}->( $route, $dir );
            $disp_route_of{$codekey}{$stopid}{$display} = 1;
        }

    }

} ## #tidy# end foreach my $key ( keys %pat)

my (%with_routes);

my $max = 0;

#my $desc_col = $stopdata->column_order_of('DescriptionCityF');

my %stoplines;

foreach my $stop ( sort keys %{ $disp_route_of{'r6dir'} } ) {

    my $desc = $stp{$stop}{Description};
    next if $desc =~ /\AVirtual Stop For/i;

    my $district = $stp{$stop}{District};

    my $bsh = 0;

    foreach my $codekey (@code_order) {
        while ( my $disp = each %{ $disp_route_of{$codekey}{$stop} } ) {

            if ( $disp =~ /\ABS[DHN]/ ) {
                delete $disp_route_of{$codekey}{$stop}{$disp};
                $bsh = 1;
                next;
            }

            next unless $disp =~ /LAST\z/;
            my $opposite = get_opposite($disp);
            if (   $disp_route_of{$codekey}{$stop}{$opposite}
                or $disp_route_of{$codekey}{$stop}{ remove_last($disp) } )
            {
                delete $disp_route_of{$codekey}{$stop}{$disp};
            }
        }
    }

    my @routes = sortbyline keys %{ $disp_route_of{'r6dir'}{$stop} };

    next unless @routes; # eliminate BSH-only stops

    #print $stoplines "$stop\t$desc\t$district\t", join( " ", @routes );

    #push @{$stoplines{$stop}} , $stop, $desc, $district , join( " ", @routes );
#    $stoplines{$stop}{DESC} = $desc;

    #my @stopsrows =  $stopdata->rows_where('PhoneID' , $stop);

    $stoplines{$stop}{DESC} = $desc_of{$stop}; 

    $stoplines{$stop}{DISTRICT} = $district;
    $stoplines{$stop}{ROUTES} = join( " ", @routes );

    foreach my $codekey (@code_order) {
        my @disps = sortbyline keys %{ $disp_route_of{$codekey}{$stop} };
        my $disp_count = scalar @disps;
        #print $stoplines "\t", $disp_count;
        #push @{$stoplines{$stop}} , $disp_count;
        $stoplines{$stop}{$codekey} = $disp_count;

        no warnings 'numeric';

        $with_routes{$codekey}[$disp_count]++;

        $max = max( $max, $disp_count );

    }

    my $note      = '';
    my $size      = '';
    my $priority  = '';
    my %has_route = %{ $disp_route_of{'route'}{$stop} };

    my $numboxes = scalar keys %{ $disp_route_of{'r6dir'}{$stop} };

    if ( $has_route{'1R'} or $has_route{'72R'} ) {
        $priority = 'A-RAPID';
        for ($numboxes) {
            if ( $_ >= 11 ) {
                $note = "CUSTOM-RAPID";
                $size = '45.75';
                next;
            }
            if ( $_ >= 6 ) {
                $note = "TEN-RAPID";
                $size = '45.75';
                next;
            }
            if ( $_ >= 2 ) {
                $note = "SIX-RAPID";
                $size = '35.25';
                next;
            }

                $note = "TWO-RAPID";
                $size = '24.75';

        }
    } ## #tidy# end if ( $has_route{'1R'} ...)
    else {
        for ($numboxes) {
            if ( $_ >= 11 ) {
                $note = "CUSTOM";
                $size = '35.25';
                $priority = 'B-BIG';
                next;
            }
            if ( $_ >= 7 ) {
                $note = "TEN";
                $size = '35.25';
                $priority = 'B-BIG';
                next;
            }
            if ($_ == 6) {
                $note = "NINE";
                $size = '32.75';
                $priority = 'B-BIG';
                next;
            }
            if ($_ == 5) {
                $note = "SIX";
                $size = '24.75';
                $priority = 'B-BIG';
                next;
            }
            if ($_ == 4) {
                $size = '22.25';
                next;
            }
            if ($_ == 3) {
                $size = '17.26';
                next;
            }
            if ($_ == 1 or $_ == 2 ) {
                $size = '17';
                next;
            }

        } ## #tidy# end given

        unless ($note) {
            if ( $bsh or $future_bsh_flags{$stop} ) {
                $note = 'BSH';
                $priority = "C-BSH"
            }
            elsif ( $alameda_shuttle_flags{$stop} ) {
                $note = 'ALAPARA';
                $priority = "C-ALAPARA";
                $size = '17' if $size eq '26'; # shrink these flags
            }
            elsif (   $known_black_flags{$stop}
                or $desc =~ /Bayfair BART/i
                or $has_route{314}
                or $has_route{356} )
            {
                $note = "BLACK";
                $priority = "D-BLACK";
            }
            elsif ($desc =~ /Transit Center/i or $desc =~ /Contra Costa College/i) {
                 $note = "CENTER";
                 $priority = "E-CENTER";            
            }
            elsif ($desc =~ /BART/i) {
                 $note = "BART";
                 $priority = "E-CENTER";            
            }
            elsif ( ( any { our $_; /[A-Z]/ and length > 2 } keys %has_route )
                and $numboxes > 2 )
            {
                $note = "LONGNUM";
                $priority = "F-LONGNUM";
            }
            elsif ($has_route{'51A'}
                or $has_route{'51B'}
                or $has_route{'1'}
                or $has_route{'72'}
                or $has_route{'72M'}
                or $has_route{'40'}
                or $has_route{'57'} )
            {
                $note = "TRUNK";
                $priority = "G-TRUNK";
            }

        } ## #tidy# end unless ($note)

    } ## #tidy# end else [ if ( $has_route{'1R'} ...)]

    #say $stoplines "\t$note\t$size\t$priority";
    #push @{$stoplines{$stop}} , $note, $size , $priority;
    $stoplines{$stop}{NOTE} = $note;
    $stoplines{$stop}{SIZE} = $size;
    $stoplines{$stop}{PRIORITY} = $priority;

} ## #tidy# end foreach my $stop ( sort keys...)

open my $stoplines, '>', 'stoplines-dir-new.txt' or die "$!";

say $stoplines jt( "StopID\tDescription\tCityCode\tLines\tNumLines\tNumBoxes", 
    'Priority');

my %priority_sizecount;
my %sizes;

#foreach my $stop (sort { 
#        (($stoplines{$a}{PRIORITY} eq '') - ($stoplines{$b}{PRIORITY} eq ''))
#        or
#        $stoplines{$b}{SIZE} <=> $stoplines{$a}{SIZE} or
#        $stoplines{$a}{PRIORITY} cmp $stoplines{$b}{PRIORITY} or
#        $stoplines{$b}{r6dir} <=> $stoplines{$a}{r6dir} or
#        $stoplines{$a}{DISTRICT} <=> $stoplines{$b}{DISTRICT} or
#        $stoplines{$a}{DESC} cmp $stoplines{$b}{DESC} 
#                 } keys %stoplines ) {
 
 foreach my $stop (sort keys %stoplines) {

    my @row = ($stop);
    foreach (qw/DESC DISTRICT ROUTES route r6dir PRIORITY/) {
       push @row, $stoplines{$stop}{$_};
    }
    say $stoplines jt(@row);

    my $priority = $stoplines{$stop}{PRIORITY};
    my $size = $stoplines{$stop}{SIZE};

    $priority_sizecount{$priority}{$size}++;
    $sizes{$size} = 1;

}

close $stoplines or die "Can't close stoplines file: $!";


my @headers = ('Size');
foreach my $priority (sort keys %priority_sizecount) {
   push @headers, sprintf('%-.7s' , $priority || '.');
}
say jt(@headers , "PRI-TOT" , "TOTAL");

my $null = ".";

my %priority_total;
foreach my $size (sort keys %sizes) {
   my @row = ($size);
   my $total = 0;
   foreach my $priority (sort keys %priority_sizecount) {
      my $count = $priority_sizecount{$priority}{$size} // 0;
      push @row, $count ;
      $total += $count ;
      $priority_total{$priority} += $count;
   }
   say jt(@row , $total - ($priority_sizecount{''}{$size} // 0), $total);
}

@headers = ('');
my $all = 0;
foreach my $priority (sort keys %priority_sizecount) {
   push @headers, $priority_total{$priority};
   $all += $priority_total{$priority};
}
say jt( @headers , $all - ( $priority_total{''} // 0 )  , $all);




say "\nWith\t", jt(@code_order);

for my $num ( reverse 1 .. $max ) {

    print $num;

    foreach my $codekey (@code_order) {
        print "\t", $with_routes{$codekey}[$num] || $null;
    }

    say '';

}

sub get_opposite {
    my $disp = shift;
    my ( $route, $dir, $last ) = split( /-/, $disp );
    return "$route-" . $opposite_of{$dir};
}

sub route {
    my ( $route, $dir ) = @_;
    return $route;
}

sub rdir {
    my ( $route, $dir ) = @_;
    return "$route-$dir";
}

sub rcdir {
    my ( $route, $dir ) = @_;
    if ( $dir eq 'CW' or $dir eq 'CC' ) {
        return rdir( $route, $dir );
    }
    else {
        return route( $route, $dir );
    }
}

sub r6dir {
    my ( $route, $dir ) = @_;
    if ( $route !~ /\A6\d\d\z/sx ) {
        return rdir( $route, $dir );
    }
    else {
        return route( $route, $dir );
    }
}

sub r6cdir {
    my ( $route, $dir ) = @_;
    if ( $route !~ /\A6\d\d\z/sx ) {
        return rcdir( $route, $dir );
    }
    else {
        return route( $route, $dir );
    }
}

sub remove_last {
    my $disp = shift;
    $disp =~ s/-LAST\z//;
    return $disp;
}
