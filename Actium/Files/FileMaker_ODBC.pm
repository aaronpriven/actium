# Actium/Files/FileMaker_ODBC.pm
# Procedural interface to Actium/O/FileMaker_ODBC.pm, for use in converting old programs

# Subversion: $Id$

# Legacy status: 4

package Actium::Files::FileMaker_ODBC;

use Actium::Preamble;
use Actium::Term;

use Actium::Cmd::Config::ActiumFM('actiumdb');

use Sub::Exporter -setup => { exports => [qw(load_tables)] };

# from old FPMerge
#   my ($file, $fparray, $fphash, $indexfield, $ignorerepeat, $ignoredupe) = @_;

# repeating fields not handled..., but nowhere in the system was it used, apparently

sub load_tables {
    my %params     = @_;
    
    my $config_obj = $params{config};

    # this bit not necessary for actium.pl based commands
    if ( not defined $config_obj ) {
        require Actium::O::Files::Ini;
        $config_obj = Actium::O::Files::Ini::->new('.actium.ini');
    }

    my $actium_db = actiumdb($config_obj);

    my %request_of = %{ $params{requests} };
    my $actium_dbh = $actium_db->dbh;

    foreach my $table ( sort keys %request_of ) {
        
        emit "Loading from $table";
        
        emit "Selecting data from table $table";
        
        my $fields;

        if (exists($request_of{$table}{fields})) {
            $fields = join(', ', @{$request_of{$table}{fields}});
        } else {
            $fields = '*';
        }
        
        emit_text "Fields: $fields";

        my $result_ref
          = $actium_dbh->selectall_arrayref( "SELECT $fields FROM $table",
            { Slice => {} } 
            );
            
        emit_done;
        
        if ( exists $request_of{$table}{array} ) {
            
            emit "Processing $table into array";
            @{ $request_of{$table}{array} } = @{$result_ref};
            # this is to make sure the same array that was passed in
            # gets the results
            emit_done;
        }

        # process into hash

        if (    exists $request_of{$table}{index_field}
            and exists $request_of{$table}{hash} )
        {

            my $ignoredupe = $request_of{$table}{ignoredupe};
            $ignoredupe //= 1;
            my $process_dupe = not $ignoredupe;
            
            emit "Processing $table into hash";

            my $hashref     = $request_of{$table}{hash};
            my $index_field = $request_of{$table}{index_field};

            if ($process_dupe) {
                
                emit "Determining whether duplicate index field ($index_field) entries";
                
                my @all_indexes = @{$actium_dbh->selectcol_arrayref(
                    "SELECT $index_field from $table")};

                if ( ( uniq @all_indexes ) == @all_indexes ) {
                    # indexes are all unique
                    $process_dupe = 0;
                    emit_no;
                }
                else {
                    emit_yes;
                }
            }

            foreach my $row_hr ( @{$result_ref} ) {

                my $index_value = $row_hr->{$index_field};
                if ($process_dupe) {
                    push @{ $hashref->{$index_value} }, $row_hr;
                }
                else {
                    $hashref->{$index_value} = $row_hr;
                }

            }
            
            emit_done;

        } ## tidy end: if ( exists $request_of...)

        emit_done;

    } ## tidy end: foreach my $table ( keys %request_of)

} ## tidy end: sub load_tables

1;

__END__

call with

load_tables (
   config => $config_obj, # Actium::O::Files::Ini object, optional
   requests => {
      table1 => { 
           index_field => 'index_field',
           array => \@array,
           hash => \%hash,
           ignoredupe => 0, # or 1
      },
      table2 => { etc. },
   },
)
