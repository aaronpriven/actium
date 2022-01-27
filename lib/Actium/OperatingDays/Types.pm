package Actium::OperatingDays::Types;
# there has got to be a better way of doing this than a
# miniscule type library but I don't know what it is.

use Type::Library
  -base,
  -declare => qw( DayCode HolidayPolicy ShortCode );
use Type::Utils;
use Types::Standard -types;

#my %OF_SHORTCODE = ( DA => '1234567', WD => '12345', WE => '67', );

#declare ShortCode, as Enum [ keys %OF_SHORTCODE ];
declare DayCode, as Str, where {length > 0 and /\A 1? 2? 3? 4? 5?  6? 7? \z/x};
declare HolidayPolicy, as Int, where { 0 <= $_ <= 7 };

#coerce DayCode, from ShortCode, via sub { $OF_SHORTCODE{$_} };

__PACKAGE__->make_immutable;
# that's a Type::Tiny make_immutable, not a Moose one

1;
