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
