
use Win32::GUI;

   my $datadialog = new Win32::GUI::DialogBox (
       -title  => "Add or Edit a Stop",
       -name => "DataDialog",
       -height => 350 ,
       -width  => 565 ,
       -left => 30 ,
       -top => 30 ,
      );

   data_cbox ($datadialog, "On Street" , "On" , 300, 1);
   data_textfield ($datadialog, "Street Number" , "StNum" , 50, 1, 400);
   data_cbox ($datadialog, "At Street" , "At" , 300, 2);
   data_cbox ($datadialog, "Near or Far Side" , "NearFar" , 50, 2, 400);
   data_cbox ($datadialog, "Sign Type" , "SignType" , 100 , 3);
   data_cbox ($datadialog, "Sign Condition" , "Condition" , 100 , 3, 200);
   data_cbox ($datadialog, "Direction" , "Direction" , 50, 3, 400);
   data_cbox ($datadialog, "Neighborhood" , "Neighborhood" , 210 , 4);
   data_cbox ($datadialog, "" , "City" , 200 , 4, 250);
   data_label ($datadialog, "City" , "City" , 30 , 4, 250);

   $datadialog->AddLabel (
        -name => "Label_TPList",
        -text => "Schedule Information" ,
        -left => 2,
        -top => 166,
        -height => 60,
        -wrap => 1,
        -width => 80,
        -align => "right",
         );

   $datadialog->AddListbox  (
       -name => "TPList",
       -sort => 1,
       -height => 100,
       -style => WS_VSCROLL,
       -width => 300,
       -tabstop => 1,
       -multisel => 0,
       -top => 162,
       -left => 92,
          );

data_tpbutton ($datadialog, 'AddTP' , "Add Schedule" , 1);
data_tpbutton ($datadialog, 'EditTP' , "Edit Schedule" , 2);
data_tpbutton ($datadialog, 'DelTP' , "Delete Schedule" , 3);

data_bigbutton ($datadialog, 'OK' , "OK" , 1);
data_bigbutton ($datadialog, 'Cancel' , "Cancel" , 2);


   $datadialog->{'City'}->AddString($_) 
      for ( sort split (/\n/ , <<EOF) );
Alameda
Alameda County
Albany
Berkeley
Contra Costa County
El Cerrito
Emeryville
Fremont
Hayward
Newark
Oakland
Piedmont
Pinole
Pleasanton
Richmond
San Francisco
San Leandro
San Pablo
Union City
EOF
     
   foreach (keys %{$datadialog}) {
       next if /^-/;
       $datadialog->$_->Show();
   }

$datadialog->Show;

print Win32::GUI::Dialog();

sub Cancel_Click {

   return $datadialog->{'StNum'}->Text();

}

sub DataDialog_Terminate {

   return -1;

}

sub data_bigbutton () {

   my ($datadialog , $name, $label, $num) = @_;

   $datadialog->AddButton (
       -name => $name ,
       -text => $label ,
       -width => 145,
       -height => 40,
       -left => (92+(155*($num-1))),
       -top => 275,
       );

}
sub data_tpbutton () {

   my ($datadialog , $name, $label, $num) = @_;

   $datadialog->AddButton (
       -name => $name ,
       -text => $label ,
       -width => 137,
       -height => 22,
       -left => 404,
       -top => (163+(35*($num-1))),
       );

}

sub data_label {

   my ($datadialog, $label, $name, $width, $num, $offset) = @_;

   $width = 80 unless $width;


   $datadialog->AddLabel (
        -name => "Label_$name",
        -text => $label ,
        -left => 2 + $offset + (80-$width),
        -top => 16+30*($num-1),
        -height => 22,
        -width => $width,
        -align => "right",
         );


}

sub data_cbox {

   my ($datadialog, $label, $name, $width, $num, $offset) = @_;

   data_label ($datadialog, $label, $name, 0, $num, $offset)
       if $label;
 
   $datadialog->AddCombobox (
        -style => WS_VISIBLE | 2 | WS_VSCROLL,
        -name => $name,
        -left => 92 + $offset,
        -tabstop => 1,
        -top => 12+30*($num-1),
        -height => 122 ,
        -width => $width ,
         );

}

sub data_textfield {

   my ($datadialog, $label, $name, $width, $num, $offset) = @_;

   data_label ($datadialog, $label, $name, 0, $num, $offset);

   $datadialog->AddTextfield (
        -name => $name,
        -left => 92 + $offset,
        -top => 12+30*($num-1),
        -tabstop => 1,
        -height => 22 ,
        -width => $width ,
         );

}
