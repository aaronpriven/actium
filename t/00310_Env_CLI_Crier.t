use strict;
use warnings;

use 5.022;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;

use Test::More 0.98 tests => 134;

BEGIN {
    note "These are tests of Actium::Env::CLI::Crier.";
    use_ok 'Actium::Env::CLI::Crier';
    use_ok 'Actium::Env::CLI::Crier::Cry';
}

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

{ my $cry = $crier->cry("Subdoulation of quantifoobar"); $cry->done; }
is( $out,
    "Subdoulation of quantifoobar.... [DONE]\n",
    "One level closed by DONE"
);

fhreset;

{ my $cry = $crier->cry("Subdoulation of quantifoobar"); }
my $expected = "Subdoulation of quantifoobar.... [ABORT]\n";
is( $out, $expected, "One level autoclosed" );

foreach my $status ( -7 .. 7 ) {
    fhreset;
    my $result;
    {
        my $cry = $crier->cry("Subdoulation of quantifoobar");
        $result = $cry->c($status);
    }
    is( $out,
        "Subdoulation of quantifoobar.... [" . $TAG_OF_STATUS{$status} . "]\n",
        "One level closed by status $status"
    );
    cmp_ok( $result, '==', $status,
        "...and the returned status is also $status" );
}

foreach my $status ( -7 .. 7 ) {
    fhreset;
    my $tag = $TAG_OF_STATUS{$status};
    my $result;
    {
        my $cry = $crier->cry("Subdoulation of quantifoobar");
        $result = $cry->c($tag);
    }
    is( $out,
        "Subdoulation of quantifoobar.... [" . $tag . "]\n",
        "One level closed by tag $tag"
    );
    cmp_ok( $result, '==', $status,
        "...and the returned status is the correct $status" );
}

fhreset;

note "Nested cries";

{
    #say "before 1";
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    #say "after 1";
    {
        #say "before 2";
        my $cry = $crier->cry("Morgozider");
        #say "after 2";
    }
    #say "after 2 & before 1 closure";
}
#say "after 1 closure";

is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider.................... [ABORT]\n"
      . "Subdoulation of quantifoobar.... [ABORT]\n",
    "Two levels autoclosed"
);

fhreset;

{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    { my $cry = $crier->cry("Morgozider"); $cry->ok }
    $cry->done;
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider.................... [OK]\n"
      . "Subdoulation of quantifoobar.... [DONE]\n",
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
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider.................... [WARN]\n"
      . "  Nimrodicator.................. [OK]\n"
      . "  Obfuscator of vanilse......... [NO]\n"
      . "Subdoulation of quantifoobar.... [DONE]\n",
    "Two levels, inner series, closed"
);

fhreset;

{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    {
        my $cry = $crier->cry("Morgozider");
        { my $cry = $crier->cry("Frimrodding the quark"); $cry->done }
        { my $cry = $crier->cry("Eouing our zyxxpth");    $cry->calm }
        $cry->warn;
    }
    { my $cry = $crier->cry("Nimrodicator");          $cry->ok }
    { my $cry = $crier->cry("Obfuscator of vanilse"); $cry->no }
    $cry->done;
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "    Frimrodding the quark....... [DONE]\n"
      . "    Eouing our zyxxpth.......... [CALM]\n"
      . "  Morgozider.................... [WARN]\n"
      . "  Nimrodicator.................. [OK]\n"
      . "  Obfuscator of vanilse......... [NO]\n"
      . "Subdoulation of quantifoobar.... [DONE]\n",
    "Three levels, mixed"
);

fhreset;
{
    my $cry
      = $crier->cry(
        "Wrappification of superlinear magmafied translengthed task strings");
    $cry->done
}
is( $out,
    "Wrappification of superlinear\n"
      . "magmafied translengthed task\n"
      . "strings......................... [DONE]\n",
    "One level wrapped"
);

fhreset;
{
    my $cry
      = $crier->cry(
        "Wrappification of superlinear magmafied translengthed task strings");
    { my $cry = $crier->cry("Short level 1 line"); $cry->done; }
    $cry->done;
}
is( $out,
    "Wrappification of superlinear\n"
      . "magmafied translengthed task\n"
      . "strings...\n"
      . "  Short level 1 line............ [DONE]\n"
      . "Wrappification of superlinear\n"
      . "magmafied translengthed task\n"
      . "strings......................... [DONE]\n",
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
        $cry->done;
    }
    $cry->done;
}
is( $out,
    "Short level 0...\n"
      . "  Wrappification of superlinear\n"
      . "  magmafied translengthed task\n"
      . "  strings....................... [DONE]\n"
      . "Short level 0................... [DONE]\n",
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
        $cry->done;
    }
    $cry->done;
}
is( $out,
    "Spatial folding process is\n"
      . "underway at this very moment...\n"
      . "  Wrappification of superlinear\n"
      . "  magmafied translengthed task\n"
      . "  strings....................... [DONE]\n"
      . "Spatial folding process is\n"
      . "underway at this very moment.... [DONE]\n",
    "Two levels, both wrapped"
);

fhreset;

note "Muted cries";

{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    $cry->c( { muted => 1 } );
}
is( $out,
    "Subdoulation of quantifoobar...\n",
    "One level muted closed by unspecified c"
);

fhreset;

{ my $cry = $crier->cry( { muted => 1 }, "Subdoulation of quantifoobar" ); }

is( $out,
    qq{Subdoulation of quantifoobar...\n},
    "One level muted on cry, autoclosed"
);

foreach my $status ( -7 .. 7 ) {
    fhreset;
    {
        my $cry = $crier->cry("Subdoulation of quantifoobar");
        $cry->c( $status, { muted => 1 } );
    }
    is( $out,
        "Subdoulation of quantifoobar...\n",
        "One level muted closed by status $status"
    );
}

foreach my $status ( -7 .. 7 ) {
    fhreset;
    my $tag = $TAG_OF_STATUS{$status};
    {
        my $cry = $crier->cry("Less nonsensical words");
        $cry->c( $tag, { muted => 1 } );
    }
    is( $out,
        "Less nonsensical words...\n",
        "One level muted closed by tag $tag",
    );
}

fhreset;

{
    my $cry = $crier->cry( { muted => 1 }, "Subdoulation of quantifoobar" );
    { my $cry = $crier->cry("Morgozider") }
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider.................... [ABORT]\n",
    "Two levels autoclosed, outer muted"
);

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    { my $cry = $crier->cry("Morgozider"); $cry->ok }
    $cry->done( { muted => 1 } );
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider.................... [OK]\n",
    "Two levels closed, outer muted"
);

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    { my $cry = $crier->cry("Morgozider");            $cry->warn }
    { my $cry = $crier->cry("Nimrodicator");          $cry->ok }
    { my $cry = $crier->cry("Obfuscator of vanilse"); $cry->no }
    $cry->done( { muted => 1 } );
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider.................... [WARN]\n"
      . "  Nimrodicator.................. [OK]\n"
      . "  Obfuscator of vanilse......... [NO]\n",
    "Two levels, inner series, closed, outer muted"
);

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    {
        my $cry = $crier->cry( { muted => 1 }, "Morgozider" );
        { my $cry = $crier->cry("Frimrodding the quark") }
        { my $cry = $crier->cry("Eouing our zyxxpth"); $cry->calm }
    }
    { my $cry = $crier->cry("Nimrodicator");          $cry->ok }
    { my $cry = $crier->cry("Obfuscator of vanilse"); $cry->no }
    $cry->done;
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "    Frimrodding the quark....... [ABORT]\n"
      . "    Eouing our zyxxpth.......... [CALM]\n"
      . "  Nimrodicator.................. [OK]\n"
      . "  Obfuscator of vanilse......... [NO]\n"
      . "Subdoulation of quantifoobar.... [DONE]\n",
    "Three levels, mixed, mid muted"
);

note "Closetext tests";

fhreset;
{
    my $cry = $crier->cry( [ "Begin task", "Task complete" ] );
    $cry->ok;
}
is( $out,
    "Begin task...\n" . "Task complete................... [OK]\n",
    "One level [otext,ctext]"
);

fhreset;
{
    my $cry = $crier->cry( [ "Hugolate", "Hugolate" ] );
    $cry->ok;
}
is( $out,
    "Hugolate........................ [OK]\n",
    "One level [otext,ctext] the same"
);

fhreset;
{
    my $cry = $crier->cry(
        { closetext => "Should not see this" },
        [ "Starting yerk", "Yerk complete" ]
    );
    $cry->ok;
}
is( $out,
    "Starting yerk...\n" . "Yerk complete................... [OK]\n",
    "One level [otext,ctext], but closetext too"
);

fhreset;
{
    my $cry = $crier->cry( { closetext => "Should not see this" },
        [ "Hugolate", "Hugolate" ] );
    $cry->ok;
}
is( $out,
    "Hugolate........................ [OK]\n",
    "One level [otext,ctext] the same, but closetext too"
);

fhreset;
{
    my $cry = $crier->cry( { closetext => "All done!" }, "Begin task" );
    $cry->ok;
}
is( $out,
    "Begin task...\n" . "All done!....................... [OK]\n",
    "One level [otext,ctext]"
);

note "Progress and over";

fhreset;
{ my $cry = $crier->cry("The progress of man"); $cry->done; }
is( $out, "The progress of man............. [DONE]\n", "Prog 0: Verify width" );

# Non-overwrite progress
fhreset;
{
    my $cry = $crier->cry("Begin urglation");
    is( $out, "Begin urglation...", "Prog A: prep" );
    $cry->prog(" 10%");
    is( $out, "Begin urglation... 10%", "Prog A: 10%" );
    $cry->prog(" 20%");
    is( $out, "Begin urglation... 10% 20%", "Prog A: 20%" );
}
is( $out, "Begin urglation... 10% 20%...... [ABORT]\n", "Prog A: done" );

# Overwrite progress
fhreset;
{
    my $cry = $crier->cry("Begin orcuation");
    is( $out, "Begin orcuation...", "Prog B: prep" );
    $cry->over(" 10%");
    is( $out, "Begin orcuation... 10%", "Prog B: 10%" );
    $cry->over(" 20%");
    is( $out, "Begin orcuation... 10%\b\b\b\b    \b\b\b\b 20%", "Prog B: 20%" );
}
is( $out, "Begin orcuation... 10%\b\b\b\b    \b\b\b\b 20%.......... [ABORT]\n",
    "Prog B: done" );

$crier->set_column_width(50);

# No timestamp
fhreset;
{ my $cry = $crier->cry("Now is the time for"); $cry->done; }
is( $out, "Now is the time for....................... [DONE]\n",
    "No Timestamp" );

# Default Timestamp

$crier->set_timestamp(1);
fhreset;
{ my $cry = $crier->cry("Now is the time for"); $cry->done; }
like(
    $out,
    qr/^\d\d:\d\d:\d\d Now is the time for\.+ \[DONE]\n/,
    "Default Timestamp"
);

# Timestamp on wrapped line
fhreset;
{
    my $cry = $crier->cry("Now is the time for all good men to come");
    $cry->done;
}
like(
    $out,
qr/^\d\d:\d\d:\d\d Now is the time for all good men\n\s+to come\.+ \[DONE]\n/,
    "Wrapped line"
);

# Custom Timestamp
$crier->set_timestamp( \&t );
fhreset;
{ my $cry = $crier->cry("Now is the time for"); $cry->done; }
like( $out, qr/^\d+-\d+-Now is the time for\.+ \[DONE]\n/, "Custom Timestamp" );

# Example Custom timestamp
sub t {
    my $level = shift;
    return sprintf "%d-%d-", $level, time();
}

$crier->set_timestamp(undef);
$crier->set_column_width(40);

note 'Testing autoclose settings';

fhreset;
{ my $cry = $crier->cry("Frimrodding quickly") }
is( $out,
    "Frimrodding quickly............. [ABORT]\n",
    "Default autoclose status"
);

$crier->set_default_status(0);
fhreset;
{ my $cry = $crier->cry("Frimrodding quickly") }
is( $out, "Frimrodding quickly............. [OK]\n", "Set autoclose status" );

fhreset;
{ my $cry = $crier->cry( "Frimrodding quickly", { tag => 'Yoyum' } ) }
is( $out, "Frimrodding quickly............. [Yoyum]\n", "Set custom tag" );

$crier->set_default_status(undef);

fhreset;
{ my $cry = $crier->cry("Frimrodding quickly") }
is( $out,
    "Frimrodding quickly............. [ABORT]\n",
    "Restored to default autoclose status"
);

fhreset;
{ my $cry = $crier->cry( "Frimrodding quickly", { status => 2 } ) }
is( $out,
    "Frimrodding quickly............. [INFO]\n",
    "Autoclose status set in cry"
);

note 'Tests of closing with c_quiet';

fhreset;
{
    my $cry = $crier->cry("Uzovating");
    $cry->c_quiet;
}
is( $out, "Uzovating...\n", "One level, quiet" );

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    { my $cry = $crier->cry("Morgozider"); $cry->c_quiet; }
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider...\n"
      . "Subdoulation of quantifoobar.... [ABORT]\n",
    "Two levels, inner quiet"
);

fhreset;
{
    my $cry = $crier->cry("Subdoulation of quantifoobar");
    { my $cry = $crier->cry("Morgozider") }
    $cry->c_quiet;
}
is( $out,
    "Subdoulation of quantifoobar...\n"
      . "  Morgozider.................... [ABORT]\n",
    "Two levels, outer quiet"
);

done_testing;
#fhreset; say "\n\n$allout\n\n";
