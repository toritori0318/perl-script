#!/usr/bin/perl

use strict;
use warnings;

use Config::YAML;
use Getopt::Long;
use Math::Round;
use Data::Dumper;

my $conf;
my $bench;

sub _bench {
    my $number = shift;
    my $ref    = shift;

    # dafault
    $ref->{test_loop}            ||= 5;
    $ref->{repeat_interval}      ||= 1;
    $ref->{client}               ||= 10;
    $ref->{client_interval}      ||= 0;
    $ref->{transaction}          ||= 10;
    $ref->{transaction_interval} ||= 0;
    $ref->{select_only}          ||= 0;
    my $select_only = ( $ref->{select_only} ) ? " -S " : "";

    print "<<<--- $number start --->>> \n";

    my @header = ();
    my @col    = ();

    # pgbench
    for ( my $j = 0 ; $j < $ref->{repeat_interval} ; $j++ ) {
        $ref->{client}      += $ref->{client_interval}      if $j > 0;
        $ref->{transaction} += $ref->{transaction_interval} if $j > 0;

        print "<<-- client = " . $ref->{client},           " -->>\n";
        print "<<-- transaction = " . $ref->{transaction}, " -->>\n";

        $bench = 0;

        for ( my $i = 0 ; $i < $ref->{test_loop} ; $i++ ) {
            my $cmd =
                $conf->{global}->{pg_home}
              . "/bin/pgbench -c "
              . $ref->{client} . " -t "
              . $ref->{transaction} . " "
              . $select_only
              . $conf->{global}->{database};
            print $cmd, "\n";

            my $result = `$cmd` or die $!;
            print $result;

            my @result_arr =
              map { /=\s([0-9.]*)\s/; $_ = $1 }
              grep { /excluding connections establishing/ }
              split( /\n/, $result );
            $bench += nearest( .1, $result_arr[0] );
        }
        push( @header, $ref->{client} . ":" . $ref->{transaction} );
        push( @col,    $bench / $ref->{test_loop} );
    }
    open LOG, ">>" . $conf->{global}->{logfile};
    print LOG "------ $number ------\n";
    print LOG join( "\t", @header ), "\n";
    print LOG join( "\t", @col ),    "\n";
    print LOG "\n";
    close LOG;
    print "<<<--- $number end --->>> \n";
}

{
    my $opt_config = 0;
    GetOptions( 'config=s' => \$opt_config );

    $opt_config ||= "./pgbench.yaml";

    $conf = Config::YAML->new( config => $opt_config );

    # global dafault
    $conf->{global}->{pg_home}          ||= "/usr/local/pgsql";
    $conf->{global}->{benchdata_create} ||= 0;
    $conf->{global}->{benchdata_scale}  ||= 25;
    $conf->{global}->{database}         ||= "pgbenchtest";
    $conf->{global}->{logfile}          ||= "./pgbench.log";

    # create bench data
    if ( $conf->{global}->{benchdata_create} ) {
        my $cmd =
            $conf->{global}->{pg_home}
          . "/bin/dropdb "
          . $conf->{global}->{database};
        print "$cmd\n";
        my $ret = system($cmd);

        #die "dropdb error!!" if $ret != 0;
        $cmd =
            $conf->{global}->{pg_home}
          . "/bin/createdb "
          . $conf->{global}->{database};
        print "$cmd\n";
        $ret = system($cmd);
        die "createdb error!!" if $ret != 0;
        $cmd =
            $conf->{global}->{pg_home}
          . "/bin/pgbench -i -s "
          . $conf->{global}->{benchdata_scale} . " "
          . $conf->{global}->{database};
        print "$cmd\n";
        $ret = system($cmd);
        die "pgbench create data error!!" if $ret != 0;
    }

    # pgbench execute
    _bench( "bench1", $conf->{bench1} ) if $conf->{bench1};
    _bench( "bench2", $conf->{bench2} ) if $conf->{bench2};
    _bench( "bench3", $conf->{bench3} ) if $conf->{bench3};
    _bench( "bench4", $conf->{bench4} ) if $conf->{bench4};
}

1;
