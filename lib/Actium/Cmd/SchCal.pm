package Actium::Cmd::SchCal 0.012;

use Actium::Preamble;
use Actium::Files::SuppCalendar;

sub OPTIONS {
    return 'signup';
}

sub START {


    my ( $class, $env ) = @_;
    my $signup = $env->signup;
    
    my $sch_cal_folder = $signup->subfolder('sch_cal');

    Actium::Files::SuppCalendar::read_supp_calendars(
        $sch_cal_folder, 
    );
    return;

}    ## tidy end: sub START

1;

