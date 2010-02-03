#!/usr/bin/perl

package Actium::Constants;

# Constants.pm
# ACTium shared constants
# The scalars are read-only and will create an error
# if they are modified. Sadly, not so with hashes
# (or arrays, if such begin to exist).

use strict;
no strict 'refs';
use warnings;

my %constants;
my ($name, $value);

BEGIN {

   %constants = 
      ( 
      	EMPTY_STR     => \q{}        ,
      	CRLF          => \qq{\cM\cJ} ,
      	SPACE         => \q{ } ,
      	MINS_IN_12HRS => \(12 * 60)  ,
      	KEY_SEPARATOR => \"\c]"      ,
	# FileMaker uses this separator for repeating fields, so I do too

	      AMPM_OFFSETS => 
	        { 
              'a' => 0 , 
              'p' => 60 * 12 ,
              'x' => 60 * 24 ,
              'b' => -60 * 12 ,
           },

         DAY_OF => 
            { qw(
                 12345 WD
			        6     SA
			        7     SU
			        67    WE
			        *2*4* TT
			        *2**5 TF
			        1*3*5 MZ
			    ) },

			DIR_OF => 
            { qw (			 
				    0 NB    1 SB
				    2 EB    3 WB
				    4 IN    5 OU
				    6 GO    7 RT
				    8 CW    9 CC
				   10 1    11 2
				   12 UP   13 DN
            ) },
            
         LINES_TO_COMBINE => 
         {
	         '59A' => 59 , 
	         '72M' => 72 , 
	         DB1 => 'DB' ,
	         DB3 => 'DB',  
	         83 => 86,  
	         386 => 86 ,
	         NC => 'NX3' , 
	         LC => 'L' , 
	         '51S' => '51' ,
         }

       );
       
   no warnings 'once';

	while ( ($name, $value) = each (%constants) ) {
      *{$name} = $value; # supports <sigil>Actium::Constants::<variable>
	}

}

sub import {
   my $caller = caller;
   
   # constants
	while ( ($name, $value) = each (%constants) ) {
  	   *{ $caller . '::' . $name } = $value;
	}

}
                
1;
