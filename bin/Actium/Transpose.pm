#!/usr/bin/perl

package Actium::Transpose;

# Transpose an AoA

use warnings;
use strict;

use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = 'transposed';

sub transposed {
    my $self = shift;
    my @result;
    my $m;

    for my $col (@{$self->[0]}) {
        push @result, [];
    }
    for my $row (@{$self}) {
        $m=0;
        for my $col (@{$row}) {
            push(@{$result[$m++]}, $col);
        }
    }
    return \@result;
}
