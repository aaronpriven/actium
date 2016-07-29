use 5.022;
use warnings;

use DateTime;
use DateTime::Format::CLDR;

use open (qw/:std :utf8/);

#my %date = (year => 2016, month => 6, day => '5', );

foreach my $year (2016..2050) {

print "--$year--\n\n";

foreach my $day ( 1 .. 366) {

next if $day == 366 and $year % 4;

my %date = ( year => $year, day_of_year => $day);

my $dt = DateTime->from_day_of_year (%date);

my @locales = qw/en_US es_US zh_Hans/;

my @formatted;

foreach my $locale (@locales) {
   my $dl = DateTime::Locale->load($locale);
   my $pattern = $dl->date_format_long;
   my $cldr = DateTime::Format::CLDR->new(
     locale      => $locale,
     pattern => $pattern, 
  );
  push @formatted,  $cldr->format_datetime($dt) ;
  #$cldr->pattern($dl->date_format_long);
  #say $cldr->format_datetime($dt);

}

say join("\t" , @formatted);

}

say "\cL";

}
