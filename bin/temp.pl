   our %daydirhash = 
        ( 
          EB_DA => 160 , 
          EB_WD => 260 , 
          EB_WE => 360 , 
          EB_SA => 460 , 
          EB_SU => 560 , 
          SB_DA => 150 , 
          SB_WD => 250 , 
          SB_WE => 350 , 
          SB_SA => 450 , 
          SB_SU => 550 , 
          WB_DA => 140 , 
          WB_WD => 240 , 
          WB_WE => 340 , 
          WB_SA => 440 , 
          WB_SU => 540 , 
          NB_DA => 130 , 
          NB_WD => 230 , 
          NB_WE => 330 , 
          NB_SA => 430 , 
          NB_SU => 530 , 
          CW_DA => 120 , 
          CW_WD => 220 , 
          CW_WE => 320 , 
          CW_SA => 420 , 
          CW_SU => 520 , 
          CC_DA => 110 , 
          CC_WD => 210 , 
          CC_WE => 310 , 
          CC_SA => 410 , 
          CC_SU => 510 , 
        );

foreach (sort { $daydirhash{$a} <=> $daydirhash{$b} } keys %daydirhash) {
   print "            $_ => $daydirhash{$_} ,\n"
}
