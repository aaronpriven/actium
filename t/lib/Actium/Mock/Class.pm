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

