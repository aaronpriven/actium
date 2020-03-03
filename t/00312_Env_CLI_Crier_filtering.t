use strict;
use warnings;

use 5.022;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;

use Test::More 0.98 tests => 14;

use Actium::Env::CLI::Crier;
use Actium::Env::CLI::Crier::Cry;

my $out;
open my $fh, '>', \$out or die $!;

my $allout;

my $crier = Actium::Env::CLI::Crier->new(
    { fh => $fh, bullets => [], column_width => 40 } );

sub fhreset {
    $crier->_ensure_start_of_line;
    close $fh or die $!;
    $allout .= $out;
    $out = q{};
    open $fh, '>', \$out or die $!;
    return;
}

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
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "    Frimrodding the quark...\n"
      . "      Eouing our zyxxpth...\n"
      . "        Shiniffing.............. [ABORT]\n"
      . "      Eouing our zyxxpth........ [CALM]\n"
      . "    Frimrodding the quark....... [OK]\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [ABORT]\n",
    "Unfiltered"
);

$crier->set_filter_above_level(0);

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
}
is( $out, "", "All filtered - nothing shown" );

$crier->set_filter_above_level(1);
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
}
is( $out, "Subdoulation of quantifoobar.... [ABORT]\n", "Max Depth = 1" );

$crier->set_filter_above_level(2);
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
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [ABORT]\n",
    "Max Depth = 2"
);

$crier->set_filter_above_level(3);
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
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "    Frimrodding the quark....... [OK]\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [ABORT]\n",
    "Max Depth = 3"
);

$crier->set_filter_above_level(4);
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
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "    Frimrodding the quark...\n"
      . "      Eouing our zyxxpth........ [CALM]\n"
      . "    Frimrodding the quark....... [OK]\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [ABORT]\n",
    "Max Depth = 4"
);

$crier->set_filter_above_level(5);
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
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "    Frimrodding the quark...\n"
      . "      Eouing our zyxxpth...\n"
      . "        Shiniffing.............. [ABORT]\n"
      . "      Eouing our zyxxpth........ [CALM]\n"
      . "    Frimrodding the quark....... [OK]\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [ABORT]\n",
    "Max Depth = 5"
);

$crier->set_filter_above_level(99);

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
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "    Frimrodding the quark...\n"
      . "      Eouing our zyxxpth...\n"
      . "        Shiniffing.............. [ABORT]\n"
      . "      Eouing our zyxxpth........ [CALM]\n"
      . "    Frimrodding the quark....... [OK]\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [ABORT]\n",
    "Max Depth = 99"
);

$crier->set_filter_above_level(undef);
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
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "    Frimrodding the quark...\n"
      . "      Eouing our zyxxpth...\n"
      . "        Shiniffing.............. [ABORT]\n"
      . "      Eouing our zyxxpth........ [CALM]\n"
      . "    Frimrodding the quark....... [OK]\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [ABORT]\n",
    "Max Depth back to Unfiltered"
);

####################################
note 'Filtering with status override';

# Baseline
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
                    $cry->done;
                }
                $cry->fail( { reason => "Severe" } );
            }
            $cry->ok;
        }
        $cry->warn;
    }
    $cry->done;
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "    Frimrodding the quark...\n"
      . "      Eouing our zyxxpth...\n"
      . "        Shiniffing.............. [DONE]\n"
      . "      Eouing our zyxxpth........ [FAIL]\n"
      . "       Severe\n"
      . "    Frimrodding the quark....... [OK]\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [DONE]\n",
    "Unfiltered"
);

# Show a severe message from the depths
$crier->set_filter_above_level(0);
$crier->set_always_show_status_above(4);

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
                    $cry->done;
                }
                $cry->fail( { reason => "Severe" } );
            }
            $cry->ok;
        }
        $cry->warn;
    }
    $cry->done;
}
is( $out,
    "      Eouing our zyxxpth........ [FAIL]\n" . "       Severe\n",
    "All filtered, but fails"
);

# Depth filtering at outermost plus a severe message
$crier->set_filter_above_level(1);
$crier->set_always_show_status_above(4);
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
                    $cry->done;
                }
                $cry->fail( { reason => "Severe" } );
            }
            $cry->ok;
        }
        $cry->warn;
    }
    $cry->done;
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "      Eouing our zyxxpth........ [FAIL]\n"
      . "       Severe\n"
      . "Subdoulation of quantifoobar.... [DONE]\n",
    "Max Depth = 1 and FAIL severity"
);

# Depth filtering at outermost plus all WARN or worse
$crier->set_filter_above_level(1);
$crier->set_always_show_status_above(1);
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
                    $cry->ok;
                }
                $cry->fail( { reason => "Severe" } );
            }
            $cry->ok;
        }
        $cry->warn;
    }
    $cry->ok;
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "      Eouing our zyxxpth........ [FAIL]\n"
      . "       Severe\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [OK]\n",
    "Max Depth = 1 and all WARN or worse severities"
);

# Depth filtering at two plus a severe message
$crier->set_filter_above_level(2);
$crier->set_always_show_status_above(4);
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
                    $cry->done;
                }
                $cry->fail( { reason => "Severe" } );
            }
            $cry->ok;
        }
        $cry->warn;
    }
    $cry->done;
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "      Eouing our zyxxpth........ [FAIL]\n"
      . "       Severe\n"
      . "  Morgozider.................... [WARN]\n"
      . "Subdoulation of quantifoobar.... [DONE]\n",
    "Max Depth = 2 and FAIL severity"
);

done_testing;
#fhreset; say "\n$allout\n";

__END__
