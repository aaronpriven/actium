# Actium/FileMaker.pm

# Subversion: $Id$

use warnings;
use strict;

package Actium::FileMaker;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;    ## no critic (StringyEval)

use Net::FileMaker;
use Readonly;

use Memoize;

Readonly my $HOST => 'consul.local';

memoize ('_fms');
memoize ('_fmdb');

sub _fms {
    my $host = shift;
    my $fms = Net::FileMaker->new(host => $host, type => 'xml');
    return $fms;
}
    
sub _fmdb {
    my $host = shift;
    my $database = shift;
    my $fms = _fms($host);
    my $fmdb = $fms->database(db => $database , user => 'Guest', pass => '');
}

sub rows {
    my $database = shift;
    my $table = shift;
    
    my $fmdb = _fmdb($HOST, $database);
    
       
    
}


#my $fmdb = $fms->database(db => 'Actium', user => 'Guest', pass => '');
#
#say join("\n" , @{$fmdb->layoutnames});
#
#my $records = $fmdb->findall(layout => 'T_Tbl' , params => { '-max' => 1});
#
#use Data::Dumper;
#
#say Dumper($records);