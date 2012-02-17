#!/ActivePerl/bin/perl

use 5.012;
use warnings;

use List::MoreUtils('natatime');
use autodie;
use FindBin('$Bin');
use lib ($Bin );

use Actium::Options('init_options');

use Actium::Sorting::Line ('sortbyline');
use Actium::Util('even_tab_columns');

init_options;


my $firstfile = shift(@ARGV);

my %line_of;
my %decals_of;
my %description_of;

open my $in, '<', $firstfile;

while ( my $line = <$in> ) {
    chomp $line;
    my ( $id, $description, $decals ) = split( /\t/, $line , 3);
    $line_of{$id} = $line;
    $decals_of{$id} = $decals ;
    $description_of{$id} = $description;
}

my $lastargv = q{};

my %results;

while ( my $line = <> ) {
    chomp $line;
    if ( $lastargv ne $ARGV ) {
        say "---\n$ARGV\n---";
        $lastargv = $ARGV;
    }

    my ( $id, $description, $new_decals ) = split( /\t/, $line , 3);
    
    next unless $line_of{$id};
    
    my $old_decals = $decals_of{$id};

    my (%is_old_decal, %is_new_decal);
    foreach my $decal (split (/\t/ , $old_decals)) {
       $is_old_decal{$decal} = 1;
    }
    foreach my $decal (split (/\t/ , $new_decals)) {
       $is_new_decal{$decal} = 1;
    } 
    
    my @unchanged;
    
    foreach my $old_decal (keys %is_old_decal) {
        if ($is_new_decal{$old_decal}) {
            delete $is_new_decal{$old_decal};
            delete $is_old_decal{$old_decal};
            push @unchanged, $old_decal;
        }
    }
    
    # The following decals are only different due to unimportant icon changes
    my @same_decals = qw(
      M-a  M-e
      M-b  M-f
      DB-a DB-g
      DB-b DB-h
      DB-c DB-i
      DB-d DB-j
      DB-e DB-k
      DB-e DB-l
      DB1-a DB1-f
      DB1-b DB1-g
      DB1-c DB1-h
      DB1-d DB1-i
      DB1-e DB1-j
      DB3-a DB3-f
      DB3-b DB3-g
      DB3-c DB3-h
      DB3-d DB3-i
      DB3-e DB3-j
      232-d 232-c
      31-b  31-g
    );
    
    my $it = natatime( 2, @same_decals );

    while ( my ( $old, $new ) = $it->() ) {
        if ($is_old_decal{$old} and $is_new_decal{$new}) {
            delete $is_old_decal{$old};
            delete $is_new_decal{$new}; 
            push @unchanged, "$old=$new";
        }
    }
    
    $old_decals = join(", " , sortbyline keys %is_old_decal);
    $new_decals = join(", " , sortbyline keys %is_new_decal);
    my $unchanged = join(", " , sortbyline @unchanged);
    
    if ($old_decals or $new_decals) {
        $results{"$id\t$description\tOld: $old_decals\tNew: $new_decals\tUnchanged: $unchanged"} = $description;
        #$results{"$id\t$description\tOld: $old_decals\tNew: $new_decals"} = $description;
    }

} ## tidy end: while ( my $line = <> )

my @results = sort { $results{$a} cmp $results{$b} } keys %results;
#my $even_columns_r = even_tab_columns(\@results);
#say join("\n" , @{$even_columns_r});
say join ("\n" , @results);
