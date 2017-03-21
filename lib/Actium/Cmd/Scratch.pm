package Actium::Cmd::Scratch 0.012;

use Actium::Preamble;

use Actium::O::DateTime;

sub START {
    
    my $obj = Actium::O::DateTime->new(strptime => "2017-02-10");
    
    use DDP;
    p $obj;
    
    say join("\n" , $obj->fulls->@*);
    say join("\n" , $obj->longs->@*);

} ## tidy end: sub START

1;

__END__
