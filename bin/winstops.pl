#!perl

# winstops.pl

use Win32::GUI;
use Win32;

use strict;
no strict 'subs';

require 'pubinflib.pl';

use constant ProgramTitle => "AC Transit Stop Signage Database";

my (@refs, @keys, %stopdata, $stopdialog, $dataresult, $tpresult);

our (%frequencies, %stops, $higheststop, @thisstopdata, %index);

init_vars();

chdir get_directory() or die "Can't change to specified directory.\n";

build_tphash();

%index = read_index();

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

my $statusbox = setup_statusbox();

our $tpdialog = setup_tpdialog();

our $datadialog = setup_datadialog();

show_stopdialog ($stopdialog);

my $savedflag = 1;

Win32::GUI::Dialog();

#### END OF MAIN

##### SUBROUTINES 

sub DelStop_Click {

   my $selection = $stopdialog->{'StopList'}->SelectedItem();

   return 1 if ($selection == -1);

   return 1 if Win32::MsgBox ("Do you really want to delete this stop?" ,
                   4 | MB_ICONQUESTION , ProgramTitle) != 6;
   # 4 is Yes/No; 6 is the response for "Yes"
     
   delete $stops{ 
     get_stopid_from_description (
        $stopdialog->{'StopList'}->GetString($selection)
        )};

   $stopdialog->{'StopList'}->RemoveItem($selection);

   my $count = $stopdialog->{'StopList'}->Count();
   $count--; # now it's the last item
   $selection = $count if $selection > $count;
   $stopdialog->{'StopList'}->Select($selection);

   $savedflag = 0;

   return 1;

}

sub StopList_DblClick {

  goto &EditStop_Click;

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

    $description = stopdescription($stopid, $stops{$stopid}, 
                   $stopdata{$stopid});

    show_stopdialog ($stopdialog);

    $selection = $stopdialog->{'StopList'}->FindStringExact($description);
    $stopdialog->{'StopList'}->Select($selection);

    return 1;

}

sub AddStop_Click {

    hide_stopdialog ($stopdialog);

    our $higheststop;

    my $stopid = $higheststop + 1;

    my $result = run_datadialog($stopid, "Adding Stop #$stopid");

    $higheststop++ if $result;

    my $description = stopdescription($stopid, $stops{$stopid},$stopdata{$_});

    show_stopdialog ($stopdialog);

    my $selection = $stopdialog->{'StopList'}->FindStringExact($description);
    $stopdialog->{'StopList'}->Select($selection);

    $savedflag = 0;

    return 1;

}

sub SaveStop_Click {

   writestops ($stopsfile, \@keys, \%stops);
   writestopdata ($stopdatafile, %stopdata);
   
   Win32::MsgBox( "Saved!" , 0 | MB_ICONINFORMATION ,
        ProgramTitle);

   $savedflag = 1;

   return 1;

}

sub QuitStop_Click {

   my $result;

   if ($savedflag) {

      my $result = Win32::MsgBox 
             ("Do you really want to quit?\r\n(We'll miss you.)" ,
                   1 | MB_ICONQUESTION , ProgramTitle);
      # 1 is OK/Cancel

      return -1 if $result == 1;  # OK
      return 1;

   }

   $result = Win32::MsgBox ("Save before quitting?" ,
                   3 | MB_ICONEXCLAMATION , ProgramTitle);
   # 3 is Yes / No / Cancel

   return 1 if $result == 2; # cancel

   return -1 if $result == 7; # no
   
   writestops ($stopsfile, \@keys, \%stops);
   writestopdata ($stopdatafile, %stopdata);
   
   return -1;

}

sub StopDialog_Terminate {

   goto &QuitStop_Click;
   # that means the close box will work exactly as the "Quit" button

}


sub setup_statusbox {

   my $statusbox = new Win32::GUI::DialogBox (
       -text  => ProgramTitle ,
       -name => "StatusBox",
      -style => (WS_BORDER | DS_MODALFRAME | WS_POPUP | 
             WS_CAPTION ) ,
      -exstyle => (WS_EX_WINDOWEDGE | 
                  WS_EX_CONTROLPARENT),
       -top => 30 ,
       -left => 30 ,
       -height => 100 ,
       -width  => 524 ,
          );

   
   $statusbox->AddLabel (
       -top => 25,
       -width => 500,
       -left => 12,
       -height => 50,
       -text => "Status",
       -name => "StatusLabel",
        );
          
    $statusbox->{'StatusLabel'}->Show;

    return $statusbox;

}


sub stopbutton {
   my $name = shift;
   my $text = shift;
   my $stopnum = shift;
   return (
       -name => $name ,
       -text => $text ,
       -tabstop => 1,
       -width => 96,
       -left => 512,
       -height => 40,
       -top => 12+(50*($stopnum-1)),
       )
}

sub setup_stopdialog {

   my $stopdialog = new Win32::GUI::DialogBox (
       -text  => ProgramTitle ,
       -name => "StopDialog",
      -style => (WS_BORDER | DS_MODALFRAME | WS_POPUP | 
             WS_MINIMIZEBOX | WS_CAPTION | WS_SYSMENU) ,
      -exstyle => (WS_EX_WINDOWEDGE | 
                  WS_EX_CONTROLPARENT),
       -top => 30 ,
       -left => 30 ,
       -height => 434 ,
       -width  => 620 ,
          );

   $stopdialog->AddListbox  (
       -name => 'StopList',
       -height => 390,
# 1 is LBS_NOTIFY, which sends clicks and double-clicks
       -style => WS_VSCROLL | 1 | WS_CHILD,
       -tabstop => 1,
       -width => 488,
       -multisel => 0,
       -top => 12,
       -left => 12,
          );

   $stopdialog->AddButton ( stopbutton ("AddStop", "&Add Stop",1) );
   $stopdialog->AddButton ( stopbutton ("EditStop", "&Edit Stop",2) );
   $stopdialog->AddButton ( stopbutton ("DelStop", "&Delete Stop",3) );
   $stopdialog->AddButton ( stopbutton ("MakeStop", "&Make Output",4) );
   $stopdialog->AddButton ( stopbutton ("SaveStop", "&Save",5) );
   $stopdialog->AddButton ( stopbutton ("QuitStop", "&Quit",6) );

 
   # the following shows all existing fields
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

   $stopdialog->{'StopList'}->Reset();

   foreach ( stopdesclist (\%stops, \%stopdata) ) {
      $stopdialog->{'StopList'}->AddString($_);
   }

   $stopdialog->Show;

}

sub put_thisstopdata_into_tplist {

    my @thisstopdata = @_;
    our %index;
    our %tphash;
 

    $datadialog->{'Data_TPList'}->Reset();

    foreach (@thisstopdata) {

       my $line = $_->{'LINE'};
       my $day = $_->{'DAY'};
       my $dir = $_->{'DIR'};
#       my $timepoint = 
#            $index{$line}{$_->{'DAY_DIR'}}{'TIMEPOINTS'}[$_->{'TPNUM'}];

       my $tp = 
            $index{$line}{$_->{'DAY_DIR'}}{'TP'}[$_->{'TPNUM'}];
       my $timepoint = $tphash{$tp};

       $datadialog->{'Data_TPList'}->AddString(
           "Line $line, $day, $dir, " .
           "Routes: " .  join ("," , @{ $_->{'ROUTES'} }) .
           " at $timepoint");

#       $datadialog->{'Data_TPList'}->AddString(
#                 "Line " . $_->{'LINE'} . ", " .
#                 $_->{'DAY'} . ", " . $_->{'DIR'} . ", " .
#                 "Routes: " .  join ("," , @{ $_->{'ROUTES'} } .
#                 "at " . )
#                 );

    }

}

sub run_datadialog {

    our @thisstopdata = ();
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

       @thisstopdata = @{$stopdata{$stopid}}
             if $stopdata{$stopid}; 
       # copy array to @thisstopdata if there is some already

       put_thisstopdata_into_tplist(@thisstopdata);

       foreach $field 
              (qw(On StNum At NearFar SignType Condition 
                 Direction Neighborhood City)) {

          $datadialog->{"Data_$field"}->Text($stops{$stopid}{$field});
          $frequencies{$field}{$stops{$stopid}{$field}}--
               if $frequencies{$field};

          # that takes away one from each frequency. We put them
          # back later.
 
       }

    } else {

       $datadialog->{'Data_TPList'}->Reset();
       # reset the TP list if it's new

    }


    $datadialog->Show;

    Win32::GUI::Dialog();

    $datadialog->Show(SW_HIDE);

    return $dataresult unless exists $stops{$stopid} or $dataresult;
     # return unless it's editing or it's an "OK"
     # in other words, return if it's an "Add Stop" that's been
     # canceled

    @{ $stopdata{$stopid} } = @thisstopdata 
          if $dataresult and scalar (@thisstopdata);
    # put the current stop data into %stopdata, if there is any

    $stops{$stopid}{'StopID'} = $stopid;
    # set the stopid.  This is redundant if it's not an 'Add'

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

   foreach ( qw(On NearFar City Direction) ) {
      next if $datadialog->{"Data_$_"}->Text();
      Win32::MsgBox( 
         "You must enter values for all of the following fields:\r\n" . 
         "On Street, Near or Far Side, Direction, and City.", 
          0 | MB_ICONSTOP , ProgramTitle);
      return 1;
   }

   unless ($datadialog->{"Data_StNum"}->Text() or 
           $datadialog->{"Data_At"}->Text() ) {
      Win32::MsgBox( 
         "You must enter values for one or both of \r\n" . 
         "At Street and Street Number.", 
          0 | MB_ICONSTOP , ProgramTitle);
      return 1;
   }

   $dataresult = 1;

   return -1;

}

sub Data_AddTP_Click {

   $datadialog->Show(SW_HIDE);

   my $result = run_tpdialog();
   push @thisstopdata, $result if ref($result);
   # each of the elements of $thisstopdata is a reference to
   # something else, so we know if we get back something that's not
   # a reference, the user hit "cancel" instead of "ok."

   @thisstopdata = sort bystopdatasort @thisstopdata;

   put_thisstopdata_into_tplist (@thisstopdata);

   $datadialog->Show;

   return 1;

}

sub Data_TPList_DblClick {

  goto &Data_EditTP_Click;

}

sub Data_EditTP_Click {

   my $selection = $datadialog->{'Data_TPList'}->SelectedItem();

   return 1 if ($selection == -1);

   $datadialog->Show(SW_HIDE);

   $thisstopdata[$selection] = run_tpdialog ($thisstopdata[$selection]);
   # this will either be a new result, or the old result if the user
   # pressed Cancel.

   @thisstopdata = sort bystopdatasort @thisstopdata;

   put_thisstopdata_into_tplist (@thisstopdata);

   $datadialog->Show;

   return 1;

}

sub Data_DelTP_Click {


   my $selection = $datadialog->{'Data_TPList'}->SelectedItem();

   return 1 if ($selection == -1);

   return 1 if Win32::MsgBox ("Do you really want to delete this schedule?" ,
                   4 | MB_ICONQUESTION , ProgramTitle) != 6;
   # 4 is Yes/No; 6 is the response for "Yes"
     
   #   delete $thisstopdata[$selection];
   # no! delete zaps the entry, but doesn't move them all forward. What
   # I wanted was this:

   splice (@thisstopdata, $selection, 1);

   $datadialog->{'Data_TPList'}->RemoveItem($selection);

   my $count = $datadialog->{'Data_TPList'}->Count();
   $count--; # now it's the last item
   $selection = $count if $selection > $count;
   $datadialog->{'Data_TPList'}->Select($selection);

   return 1;

}


sub setup_datadialog {

   my $datadialog = new Win32::GUI::DialogBox (
      -style => (WS_BORDER | DS_MODALFRAME | WS_POPUP | 
             WS_MINIMIZEBOX | WS_CAPTION | WS_SYSMENU) ,
      -exstyle => (WS_EX_WINDOWEDGE | 
                  WS_EX_CONTROLPARENT),
       -top => 30 ,
       -left => 30 ,
       -text  => "Add or Edit a Stop",
       -name => "DataDialog",
       -height => 400 ,
       -width  => 565 ,
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
       -style => WS_VSCROLL | 1 | WS_CHILD,
# 1 is LBS_NOTIFY, which sends clicks and double-clicks
       -width => 449,
       -tabstop => 1,
       -multisel => 0,
       -top => 162,
       -left => 92,
          );

   data_tpbutton ($datadialog, 'Data_AddTP' , "&Add Schedule" , 1);
   data_tpbutton ($datadialog, 'Data_EditTP' , "&Edit Schedule" , 2);
   data_tpbutton ($datadialog, 'Data_DelTP' , "&Delete Schedule" , 3);

   data_bigbutton ($datadialog, 'Data_OK' , "&OK" , 1);
   data_bigbutton ($datadialog, 'Data_Cancel' , "&Cancel" , 2);


   foreach (keys %{$datadialog}) {
       next if /^-/;
       $datadialog->$_->Show();
   }

   new Win32::GUI::Graphic(
       $datadialog, (
           -name => 'DataDividers',
           -left =>  0,
           -width => $datadialog->ScaleWidth,
           -top => 0,
           -height=> $datadialog->ScaleWidth,
            ));

   return $datadialog;

}

sub DataDividers_Paint {

     my $dc = shift;

     my $tppen = new Win32::GUI::Pen( 
             -width => 1, -color => 0 ) ;

     my $right = $datadialog->ScaleWidth() - 16;

     $dc->SelectObject($tppen);
     $dc->BeginPath();
     $dc->MoveTo ( 16, 145);
     $dc->LineTo ( $right, 145);
     $dc->MoveTo ( 16, 302);
     $dc->LineTo ( $right, 302);
     $dc->EndPath();
     $dc->StrokePath();
     $dc->Validate;

}

sub DataDialog_Terminate {

   goto &Data_Cancel_Click;

}

sub data_bigbutton () {

   my ($datadialog , $name, $label, $num) = @_;

   $datadialog->AddButton (
       -name => $name ,
       -text => $label ,
       -width => 258,
       -tabstop=>1,
       -height => 40,
       -left => (16+(268*($num-1))),
       -top => 320,
       );

}

sub data_tpbutton () {

   my ($datadialog , $name, $label, $num) = @_;

   $datadialog->AddButton (
       -name => $name ,
       -text => $label ,
       -width => 143,
       -tabstop=>1,
       -height => 22,
       -left => (93+(153*($num-1))),
       -top => 265,
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
        -style => WS_VISIBLE | 2 | 0x40 | WS_VSCROLL | WS_CHILD,
# 2 is dropdown with entry box, CBS_DROPDOWN. 
# 0x40 is CBS_AUTOHSCROLL, which allows the cursor to scroll right. 
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

sub setup_tpdialog {

   our %index;
   my $i;

   my $tpdialog = new Win32::GUI::DialogBox (
      -style => (WS_BORDER | DS_MODALFRAME | WS_POPUP | 
             WS_MINIMIZEBOX | WS_CAPTION | WS_SYSMENU) ,
      -exstyle => (WS_EX_WINDOWEDGE | 
                  WS_EX_CONTROLPARENT),
       -top => 30 ,
       -left => 30 ,
       -text  => "Add or Edit a Schedule",
       -name => "TPDialog",
       -height => 420 ,
       -width  => 620 ,
      );

     $tpdialog->AddCombobox (
        -style => WS_VISIBLE | 3 | WS_VSCROLL | WS_CHILD,
# three makes it a drop-down box only, one can't enter new values
# I am sure this is documented somewhere on MS's web site, but I don't
# have a clue where. I got it from the mailing list.
        -name => 'TP_Line',
        -left => 110,
        -tabstop => 1,
        -top => 15,
        -height => 200 ,
        -width => 105 ,
         );

     $tpdialog->{'TP_Line'}->AddString($_) foreach sort byroutes keys %index;

     $tpdialog->AddLabel (
        -name => 'TP_Line_Label',
        -left => 02,
        -text => "Select Line" ,
        -top => 19,
        -width => 90,
        -align => "right" ,
        -height => 22,
          );

     $tpdialog->AddButton (
        -name => 'TP_Line_Use' ,
        -text => "&Use this line" ,
        -left => 225,
        -top => 15,
        -tabstop => 1,
        -height => 22,
        -width => 75,
        );
        
     $tpdialog->AddButton (
        -name => 'TP_Line_Revert' ,
        -text => '&Revert to line shown below' ,
        -left => 310,
        -tabstop => 1,
        -top => 15,
        -height => 22,
        -width => 150,
        );

     $tpdialog->AddLabel (
        -name => 'TP_DayDir_Label',
        -left => 2,
        -text => "Days and\r\nDirections for\r\nLine XXX" ,
        -top => 70,
        -visible => 0,
        -width => 90,
        -align => "right" ,
        -height => 60,
          );

     for ($i = 0; $i < 6; $i++) {
        $tpdialog -> AddRadioButton (
            -name => "TP_DayDirButton$i" ,
            -text => "Button $i" ,
            -left =>  ( (int ($i/2) ) * 120 + 110) ,
            -top => ( ($i % 2) * 25 + 68) ,
            -width => 90 ,
        -tabstop => 1,
            -visible => 0,
            -height => 22 ,
            );
     }

     $tpdialog -> AddCheckbox (
         -text => "ALL ROUTES" ,
         -name => "TP_RouteboxAll" ,
         -left =>  ( 490 ) ,
         -top => ( 180) ,
         -tabstop => 1,
         -width => 90 ,
         -visible => 0,
         -height => 22 ,
         );

     for ($i = 0; $i < 8; $i++) {
        $tpdialog -> AddCheckbox (
            -name => "TP_Routebox$i" ,
            -text => "R$i" ,
            -top =>  ( (int ($i/2) ) * 25 + 205) ,
            -left => ( ($i % 2) * 50 + 490) ,
            -width => 90 ,
            -width => 45 ,
            -tabstop => 1,
            -visible => 0,
            -height => 22 ,
            );
     }
 
     $tpdialog->AddLabel (
        -name => 'TP_Routes_Label',
        -left => 490,
        -text => "Routes forr\nDA_DI" ,
        -top => 140,
        -width => 90,
        -visible => 0,
        -align => "left" ,
        -height => 40,
          );


     $tpdialog->AddLabel (
        -name => 'TP_TPS_Label',
        -left => 2,
        -text => "Timepoints\r\nfor DA_DI" ,
        -top => 140,
        -width => 90,
        -visible => 0,
        -align => "right" ,
        -height => 40,
          );

     $tpdialog->AddListbox(
       -name => "TP_TPS",
       -height => 200,
# 1 is LBS_NOTIFY, which sends clicks and double-clicks
       -style => 1 | WS_VSCROLL | WS_CHILD,
       -tabstop => 1,
       -width => 347,
       -multisel => 0,
       -top => 140,
       -left => 110,
          );

   tp_bigbutton ($tpdialog, 'TP_OK' , "&OK" , 1);
   tp_bigbutton ($tpdialog, 'TP_Cancel' , "&Cancel" , 2);

   new Win32::GUI::Graphic(
       $tpdialog, (
           -name => 'TPDividers',
           -left =>  0,
           -width => $tpdialog->ScaleWidth,
           -top => 0,
           -height=> $tpdialog->ScaleWidth,
            ));


   $tpdialog->Show(SW_HIDE);

   return $tpdialog;

}

sub TPDividers_Paint {

     my $dc = shift;

     my $tppen = new Win32::GUI::Pen( 
             -width => 1, -color => 0 ) ;

     my $right = $tpdialog->ScaleWidth() - 10;

     $dc->SelectObject($tppen);
     $dc->BeginPath();
     $dc->MoveTo ( 10, 55);
     $dc->LineTo ( $right, 55);
     $dc->MoveTo ( 10, 127);
     $dc->LineTo ( $right, 127);
#     $dc->MoveTo ( 10, 221);
#     $dc->LineTo ( $right, 221);
     $dc->MoveTo ( 10, 337);
     $dc->LineTo ( $right, 337);
     $dc->EndPath();
     $dc->StrokePath();
     $dc->Validate;

}

sub TP_Line_Use_Click {

   our $newstopdata;

   $tpdialog->{'TP_Line_Revert'}->Disable();

   my $text = $tpdialog->{'TP_Line'}->Text();
   return 1 unless $text;
   return 1 if $text eq $newstopdata->{'LINE'};

   $newstopdata->{'LINE'} = $text;

   $newstopdata->{'DAY_DIR'} = "";

   for (my $i = 0; $i < 6; $i++) {
      $tpdialog->{"TP_DayDirButton$i"}->Checked(0);
   }

   show_tpdaydirs($tpdialog,$newstopdata);
   hide_tproutes($tpdialog);

   return 1;

}

sub TP_Line_Change {

   our $newstopdata;
   $tpdialog->{'TP_Line_Revert'}->Enable() if $newstopdata->{'LINE'};
   return 1;

}

sub TP_Line_Revert_Click {

   $tpdialog->{'TP_Line_Revert'}->Disable();

   our $newstopdata;

   my $line = $newstopdata->{'LINE'};

   return 1 unless $line;
   # if it was blank, there's nothing to revert to...

   $tpdialog->{'TP_Line'}->Select(
          $tpdialog->{'TP_Line'}->FindStringExact($line) );
   show_tpdaydirs($tpdialog,$newstopdata);
   return 1;

}

sub TP_OK_Click {
   
   our $newstopdata;
   my $selection = $tpdialog->{'TP_TPS'}->SelectedItem();

   if ($selection == -1) {
      Win32::MsgBox( 
         "You must select a timepoint." , 
          0 | MB_ICONSTOP , ProgramTitle);
      return 1;
   }

   $newstopdata->{'TPNUM'} = $selection;

   unless (scalar (@{$newstopdata->{'ROUTES'}})) {
      Win32::MsgBox( 
         "You must select at least one route." , 
          0 | MB_ICONSTOP , ProgramTitle);
      return 1;
   }


   $tpresult = 1;
   return -1;

}

sub tpdaydirclick {

  our ($newstopdata, @daydirs);
  my $tpdialog = shift;
  my $button = shift;

  return 1 if $daydirs[$button] eq $newstopdata->{'DAY_DIR'};
  # don't do anything if the user just clicked on the same one

  $newstopdata->{'DAY_DIR'} = $daydirs[$button];

  my ($dir, $day) = split (/_/, $daydirs[$button]);
  $newstopdata->{'DAY'} = $day;
  $newstopdata->{'DIR'} = $dir;

  $newstopdata->{'TPNUM'} = -1;

  @{$newstopdata->{'ROUTES'}} = 
      sort byroutes 
      @{ $index{$newstopdata->{'LINE'}}{$newstopdata->{'DAY_DIR'}}{'ROUTES'}};
  # defaults to all routes, hence that above

  show_tproutes($tpdialog, $newstopdata);

}

sub tprouteclick {

   our ($newstopdata, @routes);

   my $tpdialog = shift;
   my $button = shift;

   my $count = 0;

   $newstopdata->{'ROUTES'} = [ () ];

   for (my $i = 0; $i < 8; $i++) {
      next unless $tpdialog->{"TP_Routebox$i"}->Checked();
      $count++;
      push @{$newstopdata->{'ROUTES'}} , $routes[$i];
   }
   if ($count == scalar(@routes)) {
       $tpdialog->{'TP_RouteboxAll'}->Checked(1) 
   } else {
       $tpdialog->{'TP_RouteboxAll'}->Checked(0) 
   }

   return 1;
}

sub TP_RouteboxAll_Click {

   our ($newstopdata, @routes);

   my $checked = $tpdialog->{"TP_RouteboxAll"}->Checked();

   @{$newstopdata->{'ROUTES'}} = @routes;

   for (my $i = 0; $i < scalar(@routes); $i++) {
      $tpdialog->{"TP_Routebox$i"}->Checked($checked);
   }

   return 1;

}

sub TP_Routebox0_Click { tprouteclick($tpdialog,0) }
sub TP_Routebox1_Click { tprouteclick($tpdialog,1) }
sub TP_Routebox2_Click { tprouteclick($tpdialog,2) }
sub TP_Routebox3_Click { tprouteclick($tpdialog,3) }
sub TP_Routebox4_Click { tprouteclick($tpdialog,4) }
sub TP_Routebox5_Click { tprouteclick($tpdialog,5) }
sub TP_Routebox6_Click { tprouteclick($tpdialog,6) }

sub TP_DayDirButton0_Click { tpdaydirclick($tpdialog,0) }
sub TP_DayDirButton1_Click { tpdaydirclick($tpdialog,1) }
sub TP_DayDirButton2_Click { tpdaydirclick($tpdialog,2) }
sub TP_DayDirButton3_Click { tpdaydirclick($tpdialog,3) }
sub TP_DayDirButton4_Click { tpdaydirclick($tpdialog,4) }
sub TP_DayDirButton5_Click { tpdaydirclick($tpdialog,5) }

sub TP_Cancel_Click {

   $tpresult = 0;
   return -1;
}

sub TPDialog_Terminate {
   goto &TP_Cancel_Click;
}

sub tp_bigbutton () {

   my ($tpdialog , $name, $label, $num) = @_;

   $tpdialog->AddButton (
       -name => $name ,
       -text => $label ,
       -width => 167,
       -height => 32,
       -tabstop => 1,
       -visible => 1,
       -left => (110+(180*($num-1))),
       -top => 350,
       );

}

sub run_tpdialog {

   our ($tpdialog, %index);

   my $oldstopdata = shift;
   our $newstopdata;
   undef $newstopdata;

   if ($oldstopdata) {

      $tpdialog->{'TP_Line'}->Select(
             $tpdialog->{'TP_Line'}->FindStringExact($oldstopdata->{'LINE'}) 
             );

      $tpdialog->Text("Edit Schedule");

      # have to copy the old data to the new data. just an assignment
      # won't work because that will copy the *references*...

      foreach (keys %{$oldstopdata}) {
         next if $_ eq "ROUTES"; # all but ROUTES are scalar values
         $newstopdata->{$_} = $oldstopdata->{$_}
      }
      @{$newstopdata->{'ROUTES'}} = @{$oldstopdata->{'ROUTES'}};
      # $oldstopdata{'ROUTES'} is a reference...

      show_tpdaydirs($tpdialog, $oldstopdata);

      show_tproutes($tpdialog, $oldstopdata);

   } else {

      $tpdialog->Text("Add Schedule");

      $tpdialog->{'TP_Line'}->Select(-1);
      $tpdialog->{'TP_TPS'}->Select(-1);
      
      hide_tpdaydirs($tpdialog);
      hide_tproutes($tpdialog);

   }

   $tpdialog->{'TP_Line_Revert'}->Disable();

   $tpdialog->Show;

   Win32::GUI::Dialog();

   $tpdialog->Show(SW_HIDE);

   return $newstopdata if ($tpresult);
      # if the user hit "OK", return the new data
      # ($newstopdata is modified by stuff in the Click events)

   return $oldstopdata;
      # otherwise, return the data (if any was given; if not,
      # will return undef, since that's the result of "shift ()")

}

sub show_tpdaydirs {

   my $tpdialog = shift;
   my $stopdata = shift;
   our (%index, %daydirhash, @daydirs);

   my $line = $stopdata->{'LINE'};

#   print "$line\t" , $index{$line} , "\n";

   $tpdialog->{'TP_DayDir_Label'}->Text(
        "Days and\r\nDirections for\r\nLine $line");
   $tpdialog->{'TP_DayDir_Label'}->Show;

   @daydirs = sort {$daydirhash{$a}<=>$daydirhash{$b}} 
       keys %{$index{$line}};
   
   for (my $i = 0; $i < 6; $i++) {

      if ($daydirs[$i]) {
          $tpdialog->{"TP_DayDirButton$i"}->Checked( 
              $daydirs[$i] eq $stopdata->{'DAY_DIR'});
          $tpdialog->{"TP_DayDirButton$i"}->Text($daydirs[$i]);
          $tpdialog->{"TP_DayDirButton$i"}->Show;
      } else {
          $tpdialog->{"TP_DayDirButton$i"}->Show(SW_HIDE);
      }

   }

}

sub hide_tpdaydirs {

   my $tpdialog = shift;

   for (my $i = 0; $i < 6; $i++) {
      $tpdialog->{"TP_DayDirButton$i"}->Show(SW_HIDE);
   }
   $tpdialog->{'TP_DayDir_Label'}->Show(SW_HIDE);
}


sub show_tproutes {

   our (%index, %daydirhash, %tphash, @routes);
   my $tpdialog = shift;
   my $stopdata = shift;
   my $line = $stopdata->{'LINE'};
   my $day_dir = $stopdata->{'DAY_DIR'};
   my %usedroutes = ();

   foreach (@{$stopdata->{'ROUTES'}}) {
      $usedroutes{$_} = 1;
   }
   
   $tpdialog->{'TP_Routes_Label'}->Text("Routes for\r\n$day_dir");
   $tpdialog->{'TP_Routes_Label'}->Show;

   $tpdialog->{'TP_TPS_Label'}->Text("Timepoints\r\nfor $day_dir");
   $tpdialog->{'TP_TPS_Label'}->Show;

   $tpdialog->{'TP_TPS'}->Reset();

   foreach ( @{ $index{$line}{$day_dir}{'TP'}}) {
      $tpdialog->{'TP_TPS'}->AddString ($tphash{$_}) ;
      # print $_ , "\n";
   }

   $tpdialog->{'TP_TPS'}->Select($stopdata->{'TPNUM'});

   $tpdialog->{'TP_TPS'}->Show;

   @routes = sort byroutes 
              @{ $index{$line}{$day_dir}{'ROUTES'} };
   
   my $count = 0;
   for (my $i = 0; $i < 8; $i++) {

      if ($routes[$i]) {

          if ( $usedroutes{$routes[$i]} ) {
             $count++;
             $tpdialog->{"TP_Routebox$i"}->Checked(1);
          } else {
             $tpdialog->{"TP_Routebox$i"}->Checked(0);
          }
          $tpdialog->{"TP_Routebox$i"}->Text($routes[$i]);
          $tpdialog->{"TP_Routebox$i"}->Show;
      } else {
          $tpdialog->{"TP_Routebox$i"}->Show(SW_HIDE);
      }

   }

   $tpdialog->{"TP_RouteboxAll"}->Checked($count == scalar(@routes));
   $tpdialog->{"TP_RouteboxAll"}->Show;
   $tpdialog->{'TP_OK'}->Enable;

}

sub hide_tproutes {

   my $tpdialog = shift;

   for (my $i = 0; $i < 8; $i++) {
      $tpdialog->{"TP_Routebox$i"}->Show(SW_HIDE);

   }

   $tpdialog->{'TP_TPS'}->Show(SW_HIDE);
   $tpdialog->{'TP_TPS_Label'}->Show(SW_HIDE);
   $tpdialog->{'TP_Routes_Label'}->Show(SW_HIDE);
   $tpdialog->{'TP_OK'}->Disable;
   $tpdialog->{"TP_RouteboxAll"}->Show(SW_HIDE);

}


sub read_index {

open INDEX , "<acsched.ndx" or die "Can't open index file.\n";

   local ($/) = "---\n";

   my @day_dirs;
   my @thisdir;
   my $day_dir;
   my @timepoints;
   my $line;

   while (<INDEX>) {

      chomp;
      @day_dirs = split("\n");
      $line = shift @day_dirs;
  
      foreach (@day_dirs) {
         # this $_ is local to the loop

         @thisdir = split("\t");
         $day_dir = shift @thisdir;
         @{$index{$line}{$day_dir}{"ROUTES"}} = split(/_/, shift @thisdir);

         foreach (@thisdir) {
            # another local $_

            @timepoints = split(/_/);
            push @{$index{$line}{$day_dir}{"TP"}} , $timepoints[0];
            push @{$index{$line}{$day_dir}{"TIMEPOINTS"}} , $timepoints[1];
         }

      }

   }
   return %index;

}

sub MakeStop_Click {

   $statusbox->{'StatusLabel'}->Text ("Preparing to generate files");
   $statusbox->Show();
   $stopdialog->Show(SW_HIDE);
  
   my ($description, @pickedtps);

   foreach my $stopid (sort { $a <=> $b } keys %stops) {

      next unless $stopdata{$stopid};

      $description = stopdescription($stopid, $stops{$stopid}, 
                   $stopdata{$stopid});

      $statusbox->{'StatusLabel'}->Text("Generating file for\r\n$description");

      @pickedtps = ();

      foreach (@{$stopdata{$stopid}}) {
         push @pickedtps, join ("\t" ,
              $_->{'LINE'} , 
              $_->{'DAY_DIR'} , 
              $_->{'TPNUM'} , 
              @{$_->{'ROUTES'}}
              )
      }

      build_outsched (@pickedtps);
      output_outsched($stopid, $description);

   }

   $statusbox->Show(SW_HIDE);

   Win32::MsgBox ("Output complete!" , MB_ICONINFORMATION , ProgramTitle) ;

   $stopdialog->Show();

   return 1;

}
