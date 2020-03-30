#!/usr/bin/env perl

use Actium;

my $folder = Actium::folder(shift);

my @files = $folder->glob('*.pdf');

@files = sort { Actium::byline( $a->basename, $b->basename ) } @files;

say <<'EOT';
<table border="0" cellspacing="0" cellpadding="10">
<tbody>
<tr>
EOT

my $count = 0;
foreach my $file (@files) {
    if ( $count and not( $count % 10 ) ) {
        say "</tr>\n<tr>";
    }
    my $filename = $file->basename;
    my $line     = $filename =~ s/_.*//r;
    say
qq{<td><a href="http://www.actransit.org/wp-content/uploads/$filename">$line</a></td>};

    $count++;
}

say <<'EOT';
</tr>
</tbody>
</table>
EOT
