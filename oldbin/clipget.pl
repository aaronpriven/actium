#!/usr/bin/env perl

use 5.016;
use warnings;

our $VERSION = 0.010;

use HTTP::Tiny;     ### DEP ###
use Const::Fast;    ### DEP ###
use File::Slurp::Tiny ('read_file');    ### DEP ###
use Data::Dumper;                       ### DEP ###

if ( exists $ENV{GATEWAY_INTERFACE} ) {
    print "Content-type: text/html\r\n",
      "Content-Disposition: attachment; ",
      "filename=clipper-retail-locations.html\r\n",
      "\r\n";
}

my $content;

my %begin = (
    info       => '<div class="store_info">',
    storenotes => '<div class="store_notes">',
    storename  => '<span class="storename">',
    address    => '<address>',
    phone      => 'Phone:</strong>',
    notes      => 'Notes:</strong>',
    map        => 'return showMap(',
);

my %end = (
    info       => '</div>',
    storenotes => '</div>',
    storename  => '</span>',
    address    => '</address>',
    phone      => '</span>',
    notes      => '</span>',
    map        => ')',
);

foreach ( values %begin, values %end ) {
    $_ = quotemeta($_);
}

my %eastbays = map { $_ => 1 } (
    'Alameda',    'Albany',      'Berkeley',    'Castro Valley',
    'El Cerrito', 'El Sobrante', 'Emeryville',  'Fremont',
    'Hayward',    'Milpitas',    'Newark',      'Oakland',
    'Pinole',     'Richmond',    'San Leandro', 'San Pablo',
    'Union City',
);

my %westbays = map { $_ => 1 } (
    '94103',       '94104',      '94105',     '94108',
    '94111',       'Menlo Park', 'Palo Alto', 'East Palo Alto',
    'Foster City', 'San Mateo',
);

#if (0) {
const my $URL => 'https://www.clippercard.com/ClipperWeb/goSearch.do';
my $response = HTTP::Tiny->new->get($URL);
if ( not $response->{success} ) {
    say $response->{content};
    die "Failed!\n";
}
$content = $response->{content};
#} else {
#   $content = read_file('stores.html');
#}

$content =~ s/\cM//g;

my @infos = ( $content =~ m{ $begin{info} (.*?) $end{info} }msxg );
my @notes = ( $content =~ m{ $begin{storenotes} (.*?) $end{storenotes} }msxg );

if ( @infos != @notes ) {
    warn "Unequal number of info and notes";
}

my @stores;

foreach my $i ( 0 .. $#infos ) {
    my $thisinfo   = $infos[$i];
    my $thesenotes = $notes[$i];
    my %store;

    foreach (qw(storename address phone)) {
        ( $store{$_} ) = ( $thisinfo =~ m{ $begin{$_} (.*?) $end{$_} }msx );
        $store{$_} //= q{};
    }

    my ( $street, $address_parts ) = split( /<br>/, $store{address} );
    $store{street} = $street;
    my @address_parts = split( /\R/, $address_parts );
    $store{city} = $address_parts[1];
    $store{zip}  = $address_parts[4];

    foreach (qw(notes map )) {
        ( $store{$_} ) = ( $thesenotes =~ m{ $begin{$_} (.*?) $end{$_} }msx );
        $store{$_} //= q{};

    }

    foreach ( values %store ) {
        s/\A\s+//;
        s/\s+\Z//;
    }

    push @stores, \%store;

}    ## tidy end: foreach my $i ( 0 .. $#infos)

@stores = sort {
         $a->{city} cmp $b->{city}
      || $a->{storename} cmp $b->{storename}
      || $a->{zip} cmp $b->{zip}
} @stores;

print qq[<h2>Clipper Customer Service Center at AC Transit</h2>
</p><p><a target=_blank href="http://maps.google.com/maps?q=\@1600 Franklin St., Oakland, CA&z=18">1600 Franklin St.</a>, Oakland</a><br>Open Monday through Friday, 8 a.m.&ndash;5 p.m.</p>
<p><ul> <li class="services-li">Get an adult, Youth or Senior card</li> <li class="services-li">Register a card or update your contact information</li> <li class="services-li">Replace a damaged or defective card immediately (does not apply to personalized or Clipper Direct cards)</li> <li class="services-li">Pick up replacement for a lost or stolen card.  Call Clipper Customer Service (877-878-8883) first to order a replacement card.</li> <li class="services-li">Pick up and submit Clipper forms</li> <li class="services-li">Check card balance</li> <li class="services-li">Add value</li></ul>
];

my ( $easttext, @eastcities ) = stores_table( \%eastbays, \@stores );
my ( $westtext, @westcities ) = stores_table( \%westbays, \@stores );

print
'<h2>Other Retail Locations</h2><ul style="-webkit-column-count: 3; -webkit-column-gap: 10px; -moz-column-count: 3; -moz-column-gap: 10px; column-count:3; column-gap:10px;list-style-type:square; ">';

foreach my $city ( sort ( @eastcities, @westcities ) ) {
    print q[<li><a href="#] . $city . qq[">$city</a></li>];
}

print "</ul>";

note_print();

print "<h3>East Bay</h3>$easttext";

print
  "<h3>San Francisco &amp; Peninsula (selected locations only)</h3>$westtext";

note_print();

sub note_print {

    print q{
<p>For more information, visit <a href="http://www.clippercard.com">clippercard.com</a> or call Clipper Customer Services at (877) 878-8883.</p>
<p>*BART station machines load cash only. MyTransitPlus locations within BART stations sell cards &amp; load all passes &amp; cash.</p>
};

}

sub stores_table {
    my %bays   = %{ +shift };
    my @stores = @{ +shift };

    my $tabletext = q{<table border=".5" cellspacing="0" cellpadding="6">};

    #my @headers = ('#' , 'Name' , 'Street Address' , 'City' , 'Zip', 'Phone');
    my @headers = ( 'Name', 'Street Address', 'City', 'Zip', 'Phone' );
    $_ = "<th>$_</th>" foreach @headers;

    $tabletext .= ( row(@headers) );

    my $count = 1;

    my $prevcity = '';

    my @cities;

    foreach my $store_r (@stores) {
        next unless $bays{ $store_r->{city} } or $bays{ $store_r->{zip} };

        my @fields = @{$store_r}{qw(storename street city zip phone)};

        next if $fields[0] =~ m{BART/Muni} or $fields[0] =~ /SFMTA/;

        $fields[0] =~ s/(?<!&)#\d+\s*//g;

        my $mapurl = 'http://maps.google.com/maps?q=@'
          . "$fields[1],%20$fields[2]%20CA&z=18";

        $fields[0] .= "*" if $store_r->{notes} =~ /BART Ticket/;

        $fields[1]
          = qq{<a href="$mapurl" target=_blank >} . $fields[1] . q{</a>};

        #unshift @fields, $count++;

        $fields[4] =~ s/-/&#8209;/g;

        if ( $prevcity ne $fields[2] ) {
            $prevcity = $fields[2];
            $fields[2] = qq{<span id="$fields[2]">$fields[2]</a>};
            push @cities, $prevcity;
        }

        $_ = "<td>$_</td>" foreach @fields;

        $tabletext .= row(@fields);

    }    ## tidy end: foreach my $store_r (@stores)
    $tabletext .= '</table>';

    return ( $tabletext, @cities );

}    ## tidy end: sub stores_table

sub row {
    return ( '<tr>' . join( '', @_ ) . '</tr>' );
}

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to <name> version 0.003

=head1 USAGE

 # brief working invocation example(s) using the most comman usage(s)

=head1 REQUIRED ARGUMENTS

A list of every argument that must appear on the command line when the
application is invoked, explaining what each one does, any restrictions
on where each one may appear (i.e., flags that must appear before or
after filenames), and how the various arguments and options may
interact (e.g., mutual exclusions, required combinations, etc.)

If all of the application's arguments are optional, this section may be
omitted entirely.

=over

=item B<argument()>

Description of argument.

=back

=head1 OPTIONS

A complete list of every available option with which the application
can be invoked, explaining wha each does and listing any restrictions
or interactions.

If the application has no options, this section may be omitted.

=head1 DESCRIPTION

A full description of the program and its features.

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

