# Actium/Hasi2x.pm
# Assorted commands for deriving various things from Hasi files
# (stop lists, etc.)

# Subversion: $Id$

use warnings;
use strict;

package Actium::Hasi2x;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;

use Actium::Signup;
use Actium::Util qw(jt jk keyreadable);
use Actium::Term ('output_usage');
use Actium::HastusASI::Db;
use Actium::Constants;

sub hasi2tab_START {

    my $hasidir = Actium::Signup->new('hasi');
    my $hasi    = Actium::HastusASI::Db->new( $hasidir->get_dir() );

    my $rowtype = $ARGV[0];
    
    my $iterator = $hasi->rows($rowtype);

    emit "Sending tab-delimited $rowtype data to STDOUT";

    my @columnnames = $hasi->columnnames($rowtype);
    
    push @columnnames, "${rowtype}_key" if ($hasi->has_key($rowtype));
    unshift @columnnames, "${rowtype}_id";
    
    say jt (@columnnames);

    while (my $row_r = $iterator->()) {
        my @values;
        foreach my $key (@columnnames) {
            push @values, $row_r->{$key};
        }
        say jt(@values);
    }

    emit_done;

    return;
} ## #tidy# end sub hasi2tab_START

sub hasi2tab_HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium hasi2tab -- convert an Hasi file to tab file

Usage:

actium hasi2tab ROWTYPE

Outputs to standard output text consisting of the ROWTYPE from the Hasi
files of the specified signup, converted to tab-delimited files.
It is primarily for testing the Hasi routines. It only allows parent Hasi 
rows, not child rows.
HELP

    output_usage();

    return;

} ## #tidy# end sub hasi2tab_HELP


sub checkhasis_START {
    
    use autodie;
    
    my $hasidir = Actium::Signup->new('hasi');
    my $hasi    = Actium::Hasifiles->new( $hasidir->get_dir() );
    
    my @files = glob($hasidir->make_filespec('*'));
    
    my %length_of;
    my %fieldcount_of;
                
    foreach my $file (@files) {
        next if $file =~ /\.storable\z/sx;
        next if $file =~ /\.db\z/sx;
        next if $file =~ /\.sqlite\z/sx;
        next if $file =~ /\A\./sx;
    
        open my $fh , '<' , $file;
        
        while (<$fh>) {
            
            my $length = length($_);
            my @fields = split(/,/);
            my $rowtype = $fields[0];
            
            $length_of{$rowtype} = $length if 
                ! $length_of{$rowtype} or $length_of{$rowtype} < $length;
                
            $fieldcount_of{$rowtype}{scalar @fields} = 1;
            
            if ($rowtype eq 'VDC' and scalar @fields != 7) {
                say;
            }
            
        }
    }
        
    foreach my $rowtype (sort keys %length_of) {
        print "$rowtype: length=$length_of{$rowtype}, ";
        say "numfields=" , join(' & ' , sort keys %{$fieldcount_of{$rowtype}});
    }
    
    
}

sub checkhasis_HELP {
    say 'No help written for checkhasilengths';

}


1;
            
__END__

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to <name> version 0.001

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.


=head1 OPTIONS

A complete list of every available command-line option with which
the application can be invoked, explaining what each does and listing
any restrictions or interactions.

If the application has no options, this section may be omitted.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2009 

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
