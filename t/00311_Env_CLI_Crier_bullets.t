use strict;
use warnings;

use 5.022;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;
use Actium::Env::CLI::Crier;
use Actium::Env::CLI::Crier::Cry;

use Test::More 0.98;

note "These are tests of Actium::Env::CLI::Crier.";

my %TAG_OF_STATUS = (
    7  => 'BLISS',
    6  => 'CALM',
    5  => 'PASS',
    4  => 'VALID',
    3  => 'DONE',
    2  => 'INFO',
    1  => 'YES',
    0  => 'OK',
    -1 => 'NO',
    -2 => 'WARN',
    -3 => 'ABORT',
    -4 => 'ERROR',
    -5 => 'FAIL',
    -6 => 'ALERT',
    -7 => 'PANIC',
);

my $out;
open my $fh, '>', \$out or die $!;

my $allout;

sub fhreset {
    close $fh or die $!;
    $allout .= $out;
    $out = q{};
    open $fh, '>', \$out or die $!;
    return;
}

my $crier = Actium::Env::CLI::Crier->new(
    {   fh           => $fh,
        bullets      => [ "* ", "+ ", "-", "." ],
        step         => 2,
        column_width => 42
    }
);

{
    my $cry = $crier->cry("Subdoulation of quantifobar");
    $cry->done;
}
is( $out,
    "* Subdoulation of quantifobar..... [DONE]\n",
    "One level closed by unspecified DONE"
);

fhreset;
{ my $cry = $crier->cry("Subdoulation of quantifoobar"); }
is( $out,
    "* Subdoulation of quantifoobar.... [ABORT]\n",
    "One level autoclosed"
);

foreach my $status ( -7 .. 7 ) {
    fhreset;
    my $tag = $TAG_OF_STATUS{$status};
    { my $cry = $crier->cry("Subdoulation of quantifoobar"); $cry->c($status); }
    is( $out,
        "* Subdoulation of quantifoobar.... [$tag]\n",
        "One level closed by $status"
    );
}

foreach my $status ( -7 .. 7 ) {
    fhreset;
    my $tag = $TAG_OF_STATUS{$status};
    { my $cry = $crier->cry("Subdoulation of quantifoobar"); $cry->c($tag); }
    is( $out,
        "* Subdoulation of quantifoobar.... [$tag]\n",
        "One level closed by $tag"
    );
}

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    { my $cry = $crier->cry("Morgozider") }
}
is( $out,
    "* Subdoulation of quantifoobar...\n"
      . "+   Morgozider.................... [ABORT]\n"
      . "* Subdoulation of quantifoobar.... [ABORT]\n",
    "Two levels autoclosed"
);

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    { my $cry = $crier->cry("Morgozider"); $cry->ok }
    $cry->done;
}
is( $out,
    "* Subdoulation of quantifoobar...\n"
      . "+   Morgozider.................... [OK]\n"
      . "* Subdoulation of quantifoobar.... [DONE]\n",
    "Two levels closed"
);

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    { my $cry = $crier->cry("Morgozider");            $cry->warn }
    { my $cry = $crier->cry("Nimrodicator");          $cry->ok }
    { my $cry = $crier->cry("Obfuscator of vanilse"); $cry->no }
    $cry->done;
}
my $expected
  = "* Subdoulation of quantifoobar...\n"
  . "+   Morgozider.................... [WARN]\n"
  . "+   Nimrodicator.................. [OK]\n"
  . "+   Obfuscator of vanilse......... [NO]\n"
  . "* Subdoulation of quantifoobar.... [DONE]\n",
  ;
is( $out, $expected, "Two levels, inner series, closed" );

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    {
        my $cry = $crier->cry("Morgozider");
        { my $cry = $crier->cry("Frimrodding the quark") }
        { my $cry = $crier->cry("Eouing our zyxxpth"); $cry->calm }
        $cry->warn;
    }
    { my $cry = $crier->cry("Nimrodicator");          $cry->ok }
    { my $cry = $crier->cry("Obfuscator of vanilse"); $cry->no }
    $cry->done;
}
is( $out,
    "* Subdoulation of quantifoobar...\n"
      . "+   Morgozider...\n"
      . "-     Frimrodding the quark....... [ABORT]\n"
      . "-     Eouing our zyxxpth.......... [CALM]\n"
      . "+   Morgozider.................... [WARN]\n"
      . "+   Nimrodicator.................. [OK]\n"
      . "+   Obfuscator of vanilse......... [NO]\n"
      . "* Subdoulation of quantifoobar.... [DONE]\n",
    "Three levels, mixed"
);

# Line wrapping
fhreset;
{
    my $cry = $crier->cry(
        "Wrappification of superlinear magmafied translengthed task strings");
}
is( $out,
    "* Wrappification of superlinear\n"
      . "  magmafied translengthed task\n"
      . "  strings......................... [ABORT]\n",
    "One level wrapped"
);

fhreset;
{
    my $cry = $crier->cry(
        "Wrappification of superlinear magmafied translengthed task strings");
    { my $cry = $crier->cry("Short level 1 line"); }
}
is( $out,
    "* Wrappification of superlinear\n"
      . "  magmafied translengthed task\n"
      . "  strings...\n"
      . "+   Short level 1 line............ [ABORT]\n"
      . "* Wrappification of superlinear\n"
      . "  magmafied translengthed task\n"
      . "  strings......................... [ABORT]\n",
    "Two levels, outer wrapped"
);

fhreset;
{
    my $cry = $crier->cry("Short level 0");
    {
        my $cry
          = $crier->cry(
            "Wrappification of superlinear magmafied translengthed task strings"
          );
    }
}
is( $out,
    "* Short level 0...\n"
      . "+   Wrappification of superlinear\n"
      . "    magmafied translengthed task\n"
      . "    strings....................... [ABORT]\n"
      . "* Short level 0................... [ABORT]\n",
    "Two levels, inner wrapped"
);

fhreset;
{
    my $cry
      = $crier->cry("Spatial folding process is underway at this very moment");
    {
        my $cry
          = $crier->cry(
            "Wrappification of superlinear magmafied translengthed task strings"
          );
    }
}
is( $out,
    "* Spatial folding process is\n"
      . "  underway at this very moment...\n"
      . "+   Wrappification of superlinear\n"
      . "    magmafied translengthed task\n"
      . "    strings....................... [ABORT]\n"
      . "* Spatial folding process is\n"
      . "  underway at this very moment.... [ABORT]\n",
    "Two levels, both wrapped"
);

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    {
        my $cry = $crier->cry("Morgozider");
        {
            my $cry = $crier->cry("Frimrodding the quark");
            {
                my $cry = $crier->cry("Eouing our zyxxpth");
                {
                    my $cry = $crier->cry("Shiniffing");
                }
                $cry->calm;
            }
            $cry->ok;
        }
        $cry->warn;
    }
    $cry->c_quiet;
}
is( $out,
    "* Subdoulation of quantifoobar...\n"
      . "+   Morgozider...\n"
      . "-     Frimrodding the quark...\n"
      . ".       Eouing our zyxxpth...\n"
      . ".         Shiniffing.............. [ABORT]\n"
      . ".       Eouing our zyxxpth........ [CALM]\n"
      . "-     Frimrodding the quark....... [OK]\n"
      . "+   Morgozider.................... [WARN]\n",
    "More levels than bullets"
);

$crier->set_step(0);

fhreset;
{
    my $cry = $crier->cry("Short level 0");
    {
        my $cry
          = $crier->cry(
            "Wrappification of superlinear magmafied translengthed task strings"
          );
    }
}
is( $out,
    "* Short level 0...\n"
      . "+ Wrappification of superlinear\n"
      . "  magmafied translengthed task\n"
      . "  strings......................... [ABORT]\n"
      . "* Short level 0................... [ABORT]\n",
    "No step, two levels, inner wrapped"
);

fhreset;
{
    my $cry
      = $crier->cry("Spatial folding process is underway at this very moment");
    {
        my $cry
          = $crier->cry(
            "Wrappification of superlinear magmafied translengthed task strings"
          );
    }
}
is( $out,
    "* Spatial folding process is\n"
      . "  underway at this very moment...\n"
      . "+ Wrappification of superlinear\n"
      . "  magmafied translengthed task\n"
      . "  strings......................... [ABORT]\n"
      . "* Spatial folding process is\n"
      . "  underway at this very moment.... [ABORT]\n",
    "No step, two levels, both wrapped"
);

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    {
        my $cry = $crier->cry("Morgozider");
        {
            my $cry = $crier->cry("Frimrodding the quark");
            {
                my $cry = $crier->cry("Eouing our zyxxpth");
                {
                    my $cry = $crier->cry("Shiniffing");
                }
                $cry->calm;
            }
            $cry->ok;
        }
        $cry->warn;
    }
    $cry->c_quiet;
}
is( $out,
    "* Subdoulation of quantifoobar...\n"
      . "+ Morgozider...\n"
      . "- Frimrodding the quark...\n"
      . ". Eouing our zyxxpth...\n"
      . ". Shiniffing...................... [ABORT]\n"
      . ". Eouing our zyxxpth.............. [CALM]\n"
      . "- Frimrodding the quark........... [OK]\n"
      . "+ Morgozider...................... [WARN]\n",
    "No step, More levels than bullets"
);

#say "\n\n$allout\n\n";

done_testing;
