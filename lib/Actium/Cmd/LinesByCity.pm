package Actium::Cmd::LinesByCity 0.010;

use Actium::Preamble;
use Actium::StopReports;

sub OPTIONS {
    return 'actiumfm';
}

sub HELP {
    say "linesbycity: produce list of lines by city for the web site.";
    return;
}

sub START {
    my ( $class, $env ) = @_;
    my $cry = cry("Producing lines by city report for web site");
    my $actiumdb = $env->actiumdb;
    my $html;
    my %results = Actium::StopReports::linesbycity(actiumdb => $actiumdb);
    say $results{html};
    $cry->done;

}

1;

__END__
