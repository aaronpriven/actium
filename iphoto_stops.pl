#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

use Math::Trig qw(deg2rad pi great_circle_distance asin acos);
use Scalar::Util 'looks_like_number';

my $simplefile = '/volumes/bireme/actium/db/current/SimpleStops.tab';

open my $simplefh, '<', $simplefile
  or die "Can't open $simplefile";

$/ = "\r";    # FileMaker exports CRs

use constant {
    S_PHONEID => 0,
    S_STOPID  => 1,
    S_DESC    => 2,
    S_LAT     => 3,
    S_LONG    => 4,
    S_ACTIVE => 5,
};
use constant {
    IP_ID            => 0,
    IP_NAME          => 1,
    IP_COMMENT       => 2,
    IP_FILENAME      => 3,
    IP_THUMBFILENAME => 4,
    IP_LAT           => 5,
    IP_LONG          => 6
};

use constant { RADIUS => 3956.6 * 5280 };    # feet

my ( %of_phoneid, %of_stopid );

while (<$simplefh>) {

    chomp;
    next unless $_;
    my @stop_fields = split(/\t/);
    foreach (@stop_fields) {
        s/\A\s+//;
        s/\s+\z//;
    }
    my $stopid  = $stop_fields[S_STOPID];
    my $phoneid = $stop_fields[S_PHONEID];
    $of_phoneid{$phoneid} = \@stop_fields;
    $of_stopid{$stopid}   = \@stop_fields;
}

close $simplefh or die "Can't close $simplefile";

my $get_selected_script = <<'ENDSCRIPT';

-- je parle Applescript aussi

tell application "iPhoto"
	set photolist to {}
	
	set selectedItems to selection
	
	if (count of selectedItems) is 0 then return
	
	repeat with selectedItemRef in selectedItems
		set selectedItem to contents of selectedItemRef
		
		set itemClass to class of selectedItem
		if itemClass is photo then
			set end of photolist to selectedItem
		else if itemClass is album then
			set photolist to photolist & (get photos of selectedItem)
			-- not necessary to recurse as iPhoto does that for us
		else
			error "ERROR: Don't know how to process class " & itemClass
		end if
		
	end repeat
	
	set photoInfo to {}
	
	repeat with thisPhotoRef in photolist
		set thisPhoto to contents of thisPhotoRef
		set photoProps to properties of thisPhoto
		
		set propList to {id of photoProps as string, name of photoProps, comment of photoProps, image filename of photoProps, thumbnail filename of photoProps}
		
		set myLat to latitude of photoProps
		set myLong to longitude of photoProps
		
		set end of propList to myLat
		set end of propList to myLong
		
		set my text item delimiters to character id 31
		set end of photoInfo to (propList as text)
		
	end repeat
	
end tell

set my text item delimiters to character id 30
get photoInfo as text

ENDSCRIPT

use IPC::Open2;

my $pid = open2( my $readscriptfh, my $writescriptfh, 'osascript -' );

print $writescriptfh $get_selected_script;
close $writescriptfh;

local $/ = "\x1e";

my @photos_to_process;

my @dropped_info;

PHOTO:
while (<$readscriptfh>) {
    chomp;
    s/\s+\z//g;
    next unless $_;

    my @iphoto_fields = split("\x1f");

    # say join("\t" , @iphoto_fields);

    foreach (@iphoto_fields) {
        s/\A\s+//;
        s/\s+\z//;
        $_ = '' if $_ and $_ eq 'missing value';
    }

    my ( $iphoto_id, $name, $comment, $filename, $thumbfilename, $lat, $long )
      = @iphoto_fields;

    next PHOTO if $name =~ /\*\z/;

    my $possible_id;

  FIELD:
    foreach ( $name, $comment, $filename, $thumbfilename ) {
        if (/\A(^\d{5,8})/) {
            $possible_id = $1;
            last FIELD;
        }
    }

    next PHOTO unless ( $lat and $long ) or ($possible_id);

    if ($possible_id) {

        my $length = length($possible_id);
        my $stop_data;
        if ( $length == 5 ) {
            $stop_data = $of_phoneid{$possible_id};
        }
        else {
            $possible_id = "0$possible_id" if $length == 6;
            $stop_data = $of_stopid{$possible_id};
        }

        if ($stop_data) { # yay, it found it

            my $newname = newname( $stop_data, $name );

            push @photos_to_process,
              { id   => $iphoto_id,
                name => $newname,
                comment =>
                  newcomment( \@iphoto_fields, $possible_id, $newname ),
                latitude  => $stop_data->[S_LAT],
                longitude => $stop_data->[S_LONG]
              };

            next PHOTO;

        }

    } ## tidy end: if ($possible_id)
    
    # if no possible id, then check lat and long. This allows people to
    # override computerized id

    if ( $lat and $long ) {

        my $stop_data = get_nearest_stop( $lat, $long );
        next unless $stop_data;

        my $newname = newname( $stop_data, $name );

        push @photos_to_process,
          { id      => $iphoto_id,
            name    => $newname,
            comment => newcomment( \@iphoto_fields, $possible_id, $newname ),
          };

    }

} ## tidy end: PHOTO: while (<$readscriptfh>)

close $readscriptfh;

waitpid( $pid, 0 );

#use Data::Dumper;
#say Dumper (@photos_to_process);

my @photo_commands;

foreach my $photo_r (@photos_to_process) {

    my %property = %{$photo_r};
    my $id       = $property{id};
    delete $property{id};
    my @these_commands;
  PROPERTY:
    foreach ( keys %property ) {
        my $value = $property{$_};
        next PROPERTY unless defined $value;
        $value = escape_applescript_values($value);
        push @these_commands, qq{      set $_ to $value\n};
    }

    push @photo_commands, "   tell photo id $id\n", @these_commands,
      "   end tell\n"
      if @these_commands;

}

if (@photo_commands) {
    my $all_commands
      = join( '', qq{tell application "iPhoto"\n}, @photo_commands,
        'end tell' );

    open my $changescript, "| osascript" or die "Can't open script for writing";
    say $changescript $all_commands;
    close $changescript;

    say $all_commands;

    say "\nDropped info:\n", join( "\n", @dropped_info );

}
else {
    say "No commands issued.";
}

#### END OF MAIN

sub newname {

    my $stop_data = shift;
    my $oldname   = shift;
    my $newname   = $stop_data->[S_PHONEID] . " " . $stop_data->[S_DESC];

    return undef if $oldname eq $newname;
    return $newname;

}

sub newcomment {
    my ( $iphoto_fields_r, $possible_id, $newname ) = @_;
    my $name = $iphoto_fields_r->[IP_NAME];
    $name = '' if not defined $newname;

    my $comment      = $iphoto_fields_r->[IP_COMMENT];
    my $orig_comment = $comment;
    my $filename     = $iphoto_fields_r->[IP_FILENAME];

    $filename =~ s/\..*//;
    my $nametocompare = $name;

    $filename      =~ s/[\W_]]//g;
    $nametocompare =~ s/[\W_]]//g;

    if ( lc($filename) eq lc($nametocompare) ) {
        drop( $iphoto_fields_r, $name );
        $name = '';
    }

    if ($possible_id) {
        foreach ( $name, $comment ) {
            if (/\A$possible_id/) {
                drop( $iphoto_fields_r, $_ );
                $_ = '';
            }
        }
    }

    my @commentpieces;
    push @commentpieces, $comment if $comment;
    push @commentpieces, $name    if $name;
    my $newcomment = join( " / ", @commentpieces );

    $newcomment = undef if $newcomment eq $orig_comment;

    return $newcomment;

} ## tidy end: sub newcomment

sub drop {
    my $iphoto_fields_r = shift;
    my $value           = shift;
    push @dropped_info,
        "tell photo "
      . $iphoto_fields_r->[IP_ID]
      . qq{ to set comment to comment & " / $value"};
    return;
}

sub get_nearest_stop {

    my ( $thislat, $thislong ) = @_;

    my $nearest_dist = 1500;
    my $nearest;

    foreach my $stop_data ( values %of_phoneid ) {

        my $stoplat  = $stop_data->[S_LAT];
        my $stoplong = $stop_data->[S_LONG];

        my $dist = distance( $thislat, $thislong, $stoplat, $stoplong );

        next if $dist > 1320;

        if ( $dist < $nearest_dist ) {
            $nearest      = $stop_data;
            $nearest_dist = $dist;
        }

    }

    return $nearest if $nearest;
    return;

} ## tidy end: sub get_nearest_stop

sub distance {

    # Haversine, from http://www.perlmonks.org/?node_id=150054
    my ( $lat1, $long1, $lat2, $long2 ) = @_;

    my $dlong = deg2rad($long1) - deg2rad($long2);
    my $dlat  = deg2rad($lat1) - deg2rad($lat2);

    my $a = sin( $dlat / 2 )**2
      + cos( deg2rad($lat1) ) * cos( deg2rad($lat2) ) * sin( $dlong / 2 )**2;
    my $c = 2 * ( asin( sqrt($a) ) );
    my $dist = RADIUS * $c;

    return $dist;    # returns in feet

}

sub escape_applescript_values {

    my @values = (@_);

    foreach (@values) {
        next if looks_like_number($_);
        # That's perl's idea of a number, not Applescript's, but maybe
        # it will be OK

        s{ "  }{\\"}gx;
        s{ \\ }{\\\\}gx;
        s{ \t }{\\t}gx;
        s{ \n }{\\n}gx;
        s{ \r }{\\r}gx;

        $_ = qq{"$_"};

    }

    return wantarray ? @values : $values[0];

} ## tidy end: sub escape_applescript_values
