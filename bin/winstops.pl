#!perl

# winstops.pl

use Win32::GUI;
use Win32;

use strict;
no strict 'subs';

require 'pubinflib.pl';
require 'stopslib.pl';
require 'stopdatalib.pl';

use constant ProgramTitle => "AC Transit Stop Signage Database";

my (@refs, @keys, %stopdata, $stopdialog, $dataresult);

our (%frequencies, %stops, $higheststop);

chdir get_directory() or die "Can't change to specified directory.\n";

my $stopsfile = ($ARGV[1] or "stops.txt");

@refs = readstops ($stopsfile);
@keys = @{shift @refs};
%stops = %{shift @refs};

my $stopdatafile = ( $ARGV[2] or "stopdata.txt");
%stopdata = readstopdata ($stopdatafile);

foreach (qw(City Neighborhood Direction Condition SignType NearFar On At)) {
   foreach my $stopid (keys %stops) {
      $frequencies{$_}{$stops{$stopid}{$_}}++;
   }
}

# so now $frequencies{$field} points to a hash, whose keys are all
# values of the field, and whose values are the number of times each field
# is used.

$higheststop = 0;

foreach my $stopid (keys %stops) {
   $higheststop = $stopid if $higheststop < $stopid;
}

$stopdialog = setup_stopdialog();

our $datadialog = setup_datadialog();

show_stopdialog ($stopdialog);

my $savedflag = 1;

Win32::GUI::Dialog();

##### SUBROUTINES 

sub DelStop_Click {

   my $selection = $stopdialog->{'StopList'}->SelectedItem();

   unless ($selection == -1) {
     
   delete $stops{ 
     get_stopid_from_description (
        $stopdialog->{'StopList'}->GetString($selection)
        )};

   $stopdialog->{'StopList'}->RemoveItem($selection);

   my $count = $stopdialog->{'StopList'}->Count();
   $count--; # now it's the last item
   $selection = $count if $selection > $count;
   $stopdialog->{'StopList'}->Select($selection);

   }

   $savedflag = 0;
   return 1;

}

sub EditStop_Click {

    my $selection = $stopdialog->{'StopList'}->SelectedItem();

    return 1 if $selection == -1;
    # if nothing selected, return

    my $description = $stopdialog->{'StopList'}->GetString($selection);
    my $stopid = get_stopid_from_description ($description);

    hide_stopdialog ($stopdialog);

    my $result = run_datadialog ($stopid, "Editing Stop #$stopid");

    $savedflag = 0 if $result;

    # if user pressed "ok" and not cancel, reset the saved flag

    $description = stopdescription($stopid, $stops{$stopid});

    show_stopdialog ($stopdialog);

    my $selection = $stopdialog->{'StopList'}->FindStringExact($description);
    $stopdialog->{'StopList'}->Select($selection);

    return 1;

}

sub AddStop_Click {

    hide_stopdialog ($stopdialog);

    our $higheststop;

    my $stopid = $higheststop + 1;

    my $result = run_datadialog($stopid, "Adding Stop #$stopid");

    $higheststop++ if $result;

    my $description = stopdescription($stopid, $stops{$stopid});

    show_stopdialog ($stopdialog);

    my $selection = $stopdialog->{'StopList'}->FindStringExact($description);
    $stopdialog->{'StopList'}->Select($selection);

    $savedflag = 0;

    return 1;

}

sub SaveStop_Click {

   #writestops ($stopfile, @keys, %stops);
   #writestopdata ($stopdatafile, %stops);
   
   Win32::MsgBox( "Saved!" , 0 | MB_ICONINFORMATION ,
        ProgramTitle);

   $savedflag = 1;

   return 1;

}

sub QuitStop_Click {

   my $result;

   if ($savedflag) {

      my $result = Win32::MsgBox ("Really quit?" ,
                   4 | MB_ICONQUESTION , ProgramTitle);
      # 4 is Yes/No

      return -1 if $result == 6;  # yes
      return 1;

   }

   $result = Win32::MsgBox ("Save before quitting?" ,
                   3 | MB_ICONEXCLAMATION , ProgramTitle);
   # 3 is Yes / No / Cancel

   return 1 if $result == 2; # cancel

   return -1 if $result == 7; # no
   
   #writestops ($stopfile, @keys, %stops);
   #writestopdata ($stopdatafile, %stops);
   
   return -1;

}

sub StopDialog_Terminate {

   goto &QuitStop_Click;
   # that means the close box will work exactly as the "Quit" button

}


sub stopbutton {
   my $name = shift;
   my $text = shift;
   my $stopnum = shift;
   return (
       -name => $name ,
       -text => $text ,
       -width => 96,
       -left => 512,
       -top => 12+(30*($stopnum-1)),
       )
}

sub setup_stopdialog {

   my $stopdialog = new Win32::GUI::DialogBox (
       -title  => ProgramTitle ,
       -name => "StopDialog",
       -height => 234 ,
       -width  => 620 ,
       -left => 30 ,
       -top => 30 ,
          );

   $stopdialog->AddButton ( stopbutton ("AddStop", "&Add Stop",1) );
   $stopdialog->AddButton ( stopbutton ("EditStop", "&Edit Stop",2) );
   $stopdialog->AddButton ( stopbutton ("DelStop", "&Delete Stop",3) );
   $stopdialog->AddButton ( stopbutton ("MakeStop", "&Make Output",4) );
   $stopdialog->AddButton ( stopbutton ("SaveStop", "&Save",5) );
   $stopdialog->AddButton ( stopbutton ("QuitStop", "&Quit",6) );

   $stopdialog->AddListbox  (
       -name => "StopList",
       -sort => 1,
       -height => 180,
       -style => WS_VSCROLL,
       -width => 488,
       -multisel => 0,
       -top => 12,
       -left => 12,
          );


   foreach (keys %{$stopdialog}) {
       next if /^-/;
       $stopdialog->$_->Show();
   }

   return $stopdialog;

}


sub hide_stopdialog {

   my $stopdialog = shift;
   $stopdialog->Show (SW_HIDE);

}

sub show_stopdialog {

   my $stopdialog = shift;

   $stopdialog->{'StopList'}->Reset;

   foreach ( stopdesclist (%stops) ) {
      $stopdialog->{'StopList'}->AddString($_);
   }

   $stopdialog->Show;

}


sub run_datadialog {

    my $stopid = shift;
    my $prompt = shift;

    my $field;
    our (%frequencies, $datadialog, %stops);  

    $datadialog->Text($prompt);

    foreach $field (keys %frequencies) {
       $datadialog->{"Data_$field"}->Reset();
       foreach (sort keys %{$frequencies{$field}}) {
          $datadialog->{"Data_$field"}->AddString($_) 
             if $_ ne "";

          # the 'if $_ ne ""' is because sometimes they're blank

       }
    }
    
    if (exists ($stops{$stopid})) {

       foreach $field 
              (qw(On StNum At NearFar SignType Condition 
                 Direction Neighborhood City)) {

          $datadialog->{"Data_$field"}->Text($stops{$stopid}{$field});
          $frequencies{$field}{$stops{$stopid}{$field}}--
               if $frequencies{$field};

          # that takes away one from each frequency. We put them
          # back later.

       }

    }


    $datadialog->Show;

    Win32::GUI::Dialog();

    $datadialog->Show(SW_HIDE);

    foreach my $field 
           (qw(On StNum At NearFar SignType Condition 
               Direction Neighborhood City)) {

       $stops{$stopid}{$field} = $datadialog->{"Data_$field"}->Text()
             if $dataresult;
       $frequencies{$field}{$stops{$stopid}{$field}}++ 
             if $frequencies{$field};            

       # if user didn't hit cancel, change the value. Either way,
       # add the value back to the frequency table, if there is a
       # frequency table for this field

    }

    return $dataresult;

}

sub Data_Cancel_Click {

   $dataresult = 0;
   
   return -1;

}

sub Data_OK_Click {

   $dataresult = 1;

   return -1;

}

sub setup_datadialog {

   my $datadialog = new Win32::GUI::DialogBox (
       -title  => "Add or Edit a Stop",
       -name => "DataDialog",
       -height => 350 ,
       -width  => 565 ,
       -left => 30 ,
       -top => 30 ,
      );

   data_cbox ($datadialog, "On Street" , "Data_On" , 300, 1);
   data_textfield ($datadialog, "Street Number" , "Data_StNum" , 50, 1, 400);
   data_cbox ($datadialog, "At Street" , "Data_At" , 300, 2);
   data_cbox ($datadialog, "Near or Far Side" , "Data_NearFar" , 50, 2, 400);
   data_cbox ($datadialog, "Sign Type" , "Data_SignType" , 100 , 3);
   data_cbox ($datadialog, "Sign Condition" , "Data_Condition" , 100 , 3, 200);
   data_cbox ($datadialog, "Direction" , "Data_Direction" , 50, 3, 400);
   data_cbox ($datadialog, "Neighborhood" , "Data_Neighborhood" , 210 , 4);
   data_cbox ($datadialog, "" , "Data_City" , 200 , 4, 250);
   data_label ($datadialog, "City" , "Data_City" , 30 , 4, 250);

   $datadialog->AddLabel (
        -name => "Label_Data_TPList",
        -text => "Schedule Information" ,
        -left => 2,
        -top => 166,
        -height => 60,
        -wrap => 1,
        -width => 80,
        -align => "right",
         );

   $datadialog->AddListbox  (
       -name => "Data_TPList",
       -sort => 1,
       -height => 100,
       -style => WS_VSCROLL,
       -width => 300,
       -tabstop => 1,
       -multisel => 0,
       -top => 162,
       -left => 92,
          );

   data_tpbutton ($datadialog, 'Data_AddTP' , "Add Schedule" , 1);
   data_tpbutton ($datadialog, 'Data_EditTP' , "Edit Schedule" , 2);
   data_tpbutton ($datadialog, 'Data_DelTP' , "Delete Schedule" , 3);

   data_bigbutton ($datadialog, 'Data_OK' , "OK" , 1);
   data_bigbutton ($datadialog, 'Data_Cancel' , "Cancel" , 2);


   foreach (keys %{$datadialog}) {
       next if /^-/;
       $datadialog->$_->Show();
   }

#   $datadialog->Show;

   return $datadialog;

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
