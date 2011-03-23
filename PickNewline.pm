package PickNewline;

# call picknewline with a reference to the typeglob:
# PickNewline::picknewline (\*FH)

# Assumes lines less than 8192 bytes long, and that the choices
# are one of CRLF (typical for DOS/Windows), LF (typical for Unix), 
# or CR (typical for Mac).

use strict;
no strict 'refs';
use vars qw(@ISA @EXPORT_OK);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(picknewline);

sub picknewline {

    # the tell and seek stuff restores the current position of the file.
    # I actually don't know why the position would be anything other than
    # zero, but I want to be on my best behavior...

    my $fh = shift;

    my $tell = tell $fh;

    my $nl;

    seek ($fh, 0, 0);

    local $_ = "";

    read ($fh, $_, 8192);

    if (/\cM\cJ/) {
        $nl = "\cM\cJ";
        # if there's a CRLF pair, the line ending must be CRLF.
    } elsif (/\cJ/) {
        $nl = "\cJ";
        # if there's a LF but no CRLF pair, the line ending must be LF.
    } elsif (/\cM/) {
        # if there's a CR but no LF, the line ending must be CR.
        $nl = "\cM";
    } else {
        # we don't know. Could be anything. We'll set it to undef
        $nl = undef;
    }

    seek ($fh, $tell, 0);

    return $nl;
    
}

1;
