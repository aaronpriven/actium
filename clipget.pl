#!/usr/bin/env perl

use 5.016;
use warnings;

use HTTP::Tiny;
use Const::Fast;
use File::Slurp::Tiny ('read_file');
use Data::Dumper;

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
die "Failed!\n" unless $response->{success};
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

} ## tidy end: foreach my $i ( 0 .. $#infos)

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

print "<h3>San Francisco &amp; Peninsula (selected locations only)</h3>$westtext";

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

    } ## tidy end: foreach my $store_r (@stores)
    $tabletext .= '</table>';

    return ( $tabletext, @cities );

} ## tidy end: sub stores_table

sub row {
    return ( '<tr>' . join( '', @_ ) . '</tr>' );
}

