
use Win32::GUI;

   my $linedialog = new Win32::GUI::DialogBox (
       -text  => "Pick a Line" ,
       -name => "LineDialog",
       -height => 90 ,
       -style => WS_EX_CONTEXTHELP ,
       -width  => 350 ,
       -left => 30 ,
       -top => 30 ,
      );

   $linedialog->AddLabel (
       -name => "Line_Label" ,
       -text => "Selection..." ,
       -top => 12 ,
       -left => 150 ,
        );
       

   $linedialog->AddCombobox (
        -style => WS_VISIBLE | 3 | WS_VSCROLL,
        -name => 'Line_Drop',
        -left => 12,
        -tabstop => 1,
        -top => 12,
        -height => 200 ,
        -width => 125 ,
         );


foreach ( qw(1-2-3-4 5 6 7 40-43 72-73 88 92 315 A B-BX C CB O-OX P W-WA) ) {

    $linedialog->{'Line_Drop'}->AddString($_);

}

    $linedialog->AddButton (

     -name => 'Line_OK' ,
     -text => 'OK' ,
     -tabstop => 1 ,
     -height => 22 ,
     -width => 122 ,
     -top => 40,
     -left => 12,

     );

$linedialog->Show();

Win32::GUI::Dialog();

sub LineDialog_Terminate {

return -1;

}

sub Line_Drop_Change {

   print "w";

   $linedialog->{'Line_Label'}->Text (
       $linedialog->{'Line_Drop'}->Text() );
    

}
