
use Win32::GUI;

sub BOXSTYLES () {

    ( -style => WS_BORDER | DS_MODALFRAME | WS_POPUP | 
             WS_MINIMIZEBOX | WS_CAPTION | WS_SYSMENU ,
# added WS_MINIMIZEBOX
      -exstyle => WS_EX_WINDOWEDGE | 
                  WS_EX_CONTROLPARENT,
# subtracted WS_EX_CONTEXTHELP, WS_EX_DLGMODALFRAME
       -top => 30 ,
       -left => 30 ,
    );

}

   my $tpdialog = new Win32::GUI::DialogBox (
       BOXSTYLES, 
       -title  => "Add or Edit a Schedule",
       -name => "TPDialog",
       -height => 310 ,
       -width  => 495 ,
      );

     $tpdialog->AddCombobox (
        -style => WS_VISIBLE | 3 | WS_VSCROLL,
        -name => 'TP_Line',
        -left => 110,
        -tabstop => 1,
        -top => 20,
        -height => 200 ,
        -width => 105 ,
         );

     $tpdialog->AddLabel (
        -name => 'TP_Line_Label',
        -left => 02,
        -title => "Select Line" ,
        -top => 24,
        -width => 90,
        -align => "right" ,
        -height => 22,
          );

     $tpdialog->AddButton (
        -name => 'TP_Line_Use' ,
        -title => "Use this line" ,
        -left => 225,
        -top => 20,
        -tabstop => 1,
        -height => 22,
        -width => 75,
        );
        
     $tpdialog->AddButton (
        -name => 'TP_Line_Revert' ,
        -title => 'Revert to last selected line' ,
        -left => 310,
        -tabstop => 1,
        -top => 20,
        -height => 22,
        -width => 150,
        );

     $tpdialog->AddLabel (
        -name => 'TP_DayDir_Label',
        -left => 2,
        -title => "Days and\r\nDirections for\r\nLine XXX" ,
        -top => 85,
        -width => 90,
        -align => "right" ,
        -height => 90,
          );

     for ($i = 0; $i < 6; $i++) {
        $tpdialog -> AddRadioButton (
            -name => "DayDirButton$i" ,
            -text => "Button $i" ,
            -left =>  ( (int ($i/2) ) * 120 + 110) ,
            -top => ( ($i % 2) * 25 + 83) ,
            -width => 90 ,
        -tabstop => 1,
            -visible => 1,
            -height => 22 ,
            );
     }

     $tpdialog -> AddCheckbox (
         -text => "ALL ROUTES" ,
         -name => "RouteboxAll" ,
         -left =>  ( 110) ,
         -top => ( 163) ,
        -tabstop => 1,
         -width => 90 ,
         -visible => 1,
         -height => 22 ,
         );

     for ($i = 0; $i < 7; $i++) {
        $tpdialog -> AddCheckbox (
            -name => "Routebox$i" ,
            -text => "R$i" ,
            -left =>  ( $i * 50 + 110) ,
            -top => ( 188) ,
            -width => 45 ,
        -tabstop => 1,
            -visible => 1,
            -height => 22 ,
            );
     }
 
     $i=0;
     foreach ( qw(N NF NG NH NL NV 51A)) {

        #$tpdialog->{"Routebox$i"}->Text($_);
        $i++;

     }
    
     $tpdialog->AddLabel (
        -name => 'TP_Routes_Label',
        -left => 2,
        -title => "Routes for\r\nDA_DI" ,
        -top => 172,
        -width => 90,
        -align => "right" ,
        -height => 60,
          );
   tp_bigbutton ($tpdialog, 'TP_OK' , "OK" , 1);
   tp_bigbutton ($tpdialog, 'TP_Cancel' , "Cancel" , 2);

new Win32::GUI::Graphic(
    $tpdialog, (
        -name => 'TPDividers',
        -left =>  0,
        -width => $tpdialog->ScaleWidth,
        -top => 0,
        -height=> $tpdialog->ScaleWidth,
         ));

$tpdialog->Show;

Win32::GUI::Dialog();

sub TPDividers_Paint {

     my $dc = shift;

     my $tppen = new Win32::GUI::Pen( 
             -width => 1, -color => 0 ) ;

     my $right = $tpdialog->ScaleWidth() - 10;

     $dc->SelectObject($tppen);
     $dc->BeginPath();
     $dc->MoveTo ( 10, 65);
     $dc->LineTo ( $right, 65);
     $dc->MoveTo ( 10, 147);
     $dc->LineTo ( $right, 147);
     $dc->MoveTo ( 10, 221);
     $dc->LineTo ( $right, 221);
     $dc->EndPath();
     $dc->StrokePath();
     $dc->Validate;

}


sub TPDialog_Terminate {

   return -1;

}

sub tp_bigbutton () {

   my ($tpdialog , $name, $label, $num) = @_;

   $tpdialog->AddButton (
       -name => $name ,
       -text => $label ,
       -width => 167,
       -height => 40,
       -tabstop => 1,
       -left => (110+(180*($num-1))),
       -top => 235,
       );

}
__END__

   tp_cbox ($tpdialog, "Line" , "Select Line" , 300, 1);
   tp_textfield ($tpdialog, "Street Number" , "StNum" , 50, 1, 400);
   tp_cbox ($tpdialog, "At Street" , "At" , 300, 2);
   tp_cbox ($tpdialog, "Near or Far Side" , "NearFar" , 50, 2, 400);
   tp_cbox ($tpdialog, "Sign Type" , "SignType" , 100 , 3);
   tp_cbox ($tpdialog, "Sign Condition" , "Condition" , 100 , 3, 200);
   tp_cbox ($tpdialog, "Direction" , "Direction" , 50, 3, 400);
   tp_cbox ($tpdialog, "Neighborhood" , "Neighborhood" , 210 , 4);
   tp_cbox ($tpdialog, "" , "City" , 200 , 4, 250);
   tp_label ($tpdialog, "City" , "City" , 30 , 4, 250);

   $tpdialog->AddLabel (
        -name => "Label_TPList",
        -text => "Schedule Information" ,
        -left => 2,
        -top => 166,
        -height => 60,
        -wrap => 1,
        -width => 80,
        -align => "right",
         );

   $tpdialog->AddListbox  (
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

tp_tpbutton ($tpdialog, 'AddTP' , "Add Schedule" , 1);
tp_tpbutton ($tpdialog, 'EditTP' , "Edit Schedule" , 2);
tp_tpbutton ($tpdialog, 'DelTP' , "Delete Schedule" , 3);

tp_bigbutton ($tpdialog, 'OK' , "OK" , 1);
tp_bigbutton ($tpdialog, 'Cancel' , "Cancel" , 2);


   $tpdialog->{'City'}->AddString($_) 
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
     
   foreach (keys %{$tpdialog}) {
       next if /^-/;
       $tpdialog->$_->Show();
   }

$tpdialog->Show;

print Win32::GUI::Dialog();

sub Cancel_Click {

   return $tpdialog->{'StNum'}->Text();

}

sub DataDialog_Terminate {

   return -1;

}

sub tp_bigbutton () {

   my ($tpdialog , $name, $label, $num) = @_;

   $tpdialog->AddButton (
       -name => $name ,
       -text => $label ,
       -width => 145,
       -height => 40,
       -left => (92+(155*($num-1))),
       -top => 275,
       );

}
sub tp_tpbutton () {

   my ($tpdialog , $name, $label, $num) = @_;

   $tpdialog->AddButton (
       -name => $name ,
       -text => $label ,
       -width => 137,
       -height => 22,
       -left => 404,
       -top => (163+(35*($num-1))),
       );

}

sub tp_label {

   my ($tpdialog, $label, $name, $width, $num, $offset) = @_;

   $width = 80 unless $width;


   $tpdialog->AddLabel (
        -name => "Label_$name",
        -text => $label ,
        -left => 2 + $offset + (80-$width),
        -top => 16+30*($num-1),
        -height => 22,
        -width => $width,
        -align => "right",
         );


}

sub tp_cbox {

   my ($tpdialog, $label, $name, $width, $num, $offset) = @_;

   tp_label ($tpdialog, $label, $name, 0, $num, $offset)
       if $label;
 
   $tpdialog->AddCombobox (
        -style => WS_VISIBLE | 2 | WS_VSCROLL,
        -name => $name,
        -left => 92 + $offset,
        -tabstop => 1,
        -top => 12+30*($num-1),
        -height => 122 ,
        -width => $width ,
         );

}

sub tp_textfield {

   my ($tpdialog, $label, $name, $width, $num, $offset) = @_;

   tp_label ($tpdialog, $label, $name, 0, $num, $offset);

   $tpdialog->AddTextfield (
        -name => $name,
        -left => 92 + $offset,
        -top => 12+30*($num-1),
        -tabstop => 1,
        -height => 22 ,
        -width => $width ,
         );

}
