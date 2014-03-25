package English::Control;

our $VERSION = '0.00';

=head1 NAME

English::Control - Control-character aliases for punctuation variables

=head1 SYNOPSIS

    use English::Control;
    ...
    if (${^ERRNO} =~ /denied/) { ... }

=head1 DESCRIPTION

This module provides aliases for the built-in variables whose
names no one seems to like to read.  Variables with side-effects
which get triggered just by accessing them (like $0) will still 
be affected.

Unlike the English module, this module uses versions of the English
names that begin with a control character. So where English uses
$ARG as an alias for $_, this module uses ${^ARG}.

For those variables that have an B<awk> version, both long
and short English alternatives are provided.  For example, 
the C<$/> variable can be referred to either ${^RS} or 
${^INPUT_RECORD_SEPARATOR} if you are using this module.

Because variables beginning with a control character are forced to
be in package main, the effects of English::Control are global
throughout your program, and affects all modules once English::Control
is required.  Variables beginning with a control character (except
those beginning with ^_) are reserved by Perl, so this might conflict
with a future version of Perl.

=head1 PERFORMANCE

This module does not provide aliases for the regex variables $` ,
*' , and $&. So the performance penalty caused by using those
variables is not incurred. Use the punctuation variables directly,
or (better yet) use the /p regexp flag and use the ${^PREMATCH},
${^POSTMATCH}, and ${^MATCH} variables, which are provided by perl
directly.

=cut

no warnings;

*{^ARG} = *_;

# Matching.

*{^LAST_PAREN_MATCH}     = *+;
*{^LAST_SUBMATCH_RESULT} = *^N;
*{^LAST_MATCH_START}     = *-{ARRAY};
*{^LAST_MATCH_END}       = *+{ARRAY};

# Input.

*{^INPUT_LINE_NUMBER}      = *.;
*{^NR}                     = *.;
*{^INPUT_RECORD_SEPARATOR} = */;
*{^RS}                     = */;

# Output.

*{^OUTPUT_AUTOFLUSH}        = *|;
*{^OUTPUT_FIELD_SEPARATOR}  = *,;
*{^OFS}                     = *,;
*{^OUTPUT_RECORD_SEPARATOR} = *\;
*{^ORS}                     = *\;

# Interpolation "constants".

*{^LIST_SEPARATOR}      = *";
*{^SUBSCRIPT_SEPARATOR} = *;;
*{^SUBSEP}              = *;;

# Formats

*{^FORMAT_PAGE_NUMBER}           = *%;
*{^FORMAT_LINES_PER_PAGE}        = *=;
*{^FORMAT_LINES_LEFT}            = *-;
*{^FORMAT_NAME}                  = *~;
*{^FORMAT_TOP_NAME}              = *^;
*{^FORMAT_LINE_BREAK_CHARACTERS} = *:;
*{^FORMAT_FORMFEED}              = *^L;

# Error status.

*{^CHILD_ERROR}       = *?;
*{^OS_ERROR}          = *!;
*{^ERRNO}             = *!;
*{^EXTENDED_OS_ERROR} = *^E;
*{^EVAL_ERROR}        = *@;

# Process info.

*{^PROCESS_ID}         = *$;
*{^PID}                = *$;
*{^REAL_USER_ID}       = *<;
*{^UID}                = *<;
*{^EFFECTIVE_USER_ID}  = *>;
*{^EUID}               = *>;
*{^REAL_GROUP_ID}      = *(;
*{^GID}                = *(;
*{^EFFECTIVE_GROUP_ID} = *);
*{^EGID}               = *);
*{^PROGRAM_NAME}       = *0;

# Internals.

*{^PERL_VERSION}            = *^V;
*{^ACCUMULATOR}             = *^A;
*{^COMPILING}               = *^C;
*{^DEBUGGING}               = *^D;
*{^SYSTEM_FD_MAX}           = *^F;
*{^INPLACE_EDIT}            = *^I;
*{^PERLDB}                  = *^P;
*{^LAST_REGEXP_CODE_RESULT} = *^R;
*{^EXCEPTIONS_BEING_CAUGHT} = *^S;
*{^BASETIME}                = *^T;
*{^WARNING}                 = *^W;
*{^EXECUTABLE_NAME}         = *^X;
*{^OSNAME}                  = *^O;

# Deprecated.

#*{^ARRAY_BASE}       = *[;
#*{^OFMT}             = *#;
#*{^OLD_PERL_VERSION} = *];

1;
