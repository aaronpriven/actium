package Actium::AllUtils 0.010;

# probably to move to Actium::Preamble eventually

use 5.022;
use warnings;

BEGIN {
    # make the 'u' package an alias to the Actium::AllUtils package
    no strict 'refs';
    *u:: = \*Actium::AllUtils::;
}

use Actium::Constants;
#use Actium::Crier(':all');
use Actium::Sorting::Line(qw/byline sortbyline/);
use Actium::Util(':all');
use Carp qw(cluck longmess shortmess);    ### DEP ###
use Const::Fast;                          ### DEP ###
use HTML::Entities (qw[encode_entities decode_entities]);    ### DEP ###
use List::AllUtils(':all');                                  ### DEP ###
use Module::Runtime ('require_module');                      ### DEP ###
use Params::Validate;                                        ### DEP ###
use POSIX (qw/ceil floor/);                                  ### DEP ###
use Text::Trim;                                              ### DEP ###

BEGIN {
    # modules with no 'all' tag
    require Scalar::Util;
    Scalar::Util::->import(@Scalar::Util::EXPORT_OK);
    require Hash::Util;
    Hash::Util::->import(@Hash::Util::EXPORT_OK);
}

sub lock_hashref_recurse  {
    goto &Hash::Util::lock_hashref_recurse ;
}

sub unlock_hashref_recurse  {
    goto &Hash::Util::unlock_hashref_recurse ;
}

1;

__END__
