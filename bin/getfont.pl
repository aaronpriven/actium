use Win32::GUI;

$W = new Win32::GUI::Window(-name => 'Fred' , -height => 100 , -width => 200);

  $Font = $W->GetFont();
  %hash = Win32::GUI::Font::Info( $Font );



foreach (keys %hash) {

   print "$_\t$hash{$_}\n";

}

