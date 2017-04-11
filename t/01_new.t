use strict;
use Test::More;

require Amon2::Setup::Flavor::JSONAPI;
Amon2::Setup::Flavor::JSONAPI->import;
note("new");
my $obj = new_ok("Amon2::Setup::Flavor::JSONAPI");

# diag explain $obj

done_testing;
