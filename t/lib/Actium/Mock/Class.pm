package Actium::Mock::Class 0.014;

my $sampletext = <<EOT;
This Is the Title of This Story, Which Is Also Found Several Times in the Story
Itself.\N{EURO SIGN}
EOT

sub sampletext { return $sampletext }

sub new {
    my $class = shift;
    my $id = shift // 'null_id';
    return bless { id => $id }, $class;
}

sub meth {
    my $self = shift;
    my $text = $sampletext;
    $text .= "Arguments: @_\n" if @_;
    return $text;
}

sub id {
    my $self = shift;
    return $self->{id};
}

package Actium::Mock::Class::WithLayers {
    our @ISA = 'Actium::Mock::Class';
    sub meth_layers {':encoding(iso-8859-15)'}
}

1;

__END__

=head1 COPYRIGHT & LICENSE

Copyright 2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

