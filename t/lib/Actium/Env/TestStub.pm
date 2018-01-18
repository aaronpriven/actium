package Actium::Env::TestStub 0.014;

my $object = bless {}, 'Actium::Env::TestStub';

sub default_crier { return $object }
sub cry           { return $object }
sub new           { return $object }
sub last_cry      { return $object }

sub prog     {return}
sub over     {return}
sub text     {return}
sub cry_text {return}
sub done     {return}

# these should perhaps be moved to a role of some kind...

sub d_emerg { done 'EMERG' }
sub d_panic { done 'PANIC' }
sub d_havoc { done 'HAVOC' }
sub d_alert { done 'ALERT' }
sub d_crit  { done 'CRIT' }
sub d_darn  { done 'DARN' }
sub d_fail  { done 'FAIL' }
sub d_fatal { done 'FATAL' }
sub d_argh  { done 'ARGH' }
sub d_error { done 'ERROR' }
sub d_err   { done 'ERR' }
sub d_oops  { done 'OOPS' }
sub d_warn  { done 'WARN' }
sub d_note  { done 'NOTE' }
sub d_info  { done 'INFO' }
sub d_ok    { done 'OK' }
sub d_debug { done 'DEBUG' }
sub d_notry { done 'NOTRY' }
sub d_unk   { done 'UNK' }
sub d_yes   { done 'YES' }
sub d_pass  { done 'PASS' }
sub d_no    { done 'NO' }

1;
