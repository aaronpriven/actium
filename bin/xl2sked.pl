#!/usr/bin/env perl -pi -0777

# legacy status: 1

# Excel for Mac outputs text files that use CR instead of LF as line 
# boundaries, and which may have extra fields tacked on to the end
# which confuse the sked reading program. This truncates those.

s/\cM/\cJ/g;
s/\s+\cJ/\cJ/g;

$_ .= "\cJ" unless substr ($_ , -1, 1) eq "\cJ";
