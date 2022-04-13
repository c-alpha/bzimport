#!/usr/bin/env perl -w
###
# Copyright (c) 2016,2022 by condition-alpha.com  /  All rights reserved.
###
use strict;
use warnings;
use REST::Client;
use Cpanel::JSON::XS qw(encode_json decode_json);
use Text::CSV_XS;
use Term::Prompt;
#use Data::Dumper;  # for print debugging

###
#  read CSV file name from command line
#
if ($#ARGV != 0) {
  print "Usage: bzimport.pl <filename>\n";
  exit;
}
my $filename = $ARGV[0];

###
#  read descriptions of new bugs from file
#
my @bugs;
my @parents;
my @subtasks;
# Read/parse CSV
my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });
open my $fh, "<:encoding(utf8)", $filename or die "\"".$filename."\": $!";
print "Reading \"".$filename."\"...\n";
my $product;
my $component;
my $summary;
my $description;
my $severity;
my $priority;
my $blocks;
my $depends_on;
my $milestone;
my $version;
my $os;
my $platform;
$csv->bind_columns (\$product, \$component, \$summary, \$description, \$severity, \$priority, \$blocks, \$depends_on, \$milestone, \$version, \$os, \$platform);
while (my $row = $csv->getline ($fh)) {
  unless (($product eq "Product") || ($product eq "")) {
    my %bug = (
	       product => $product,
	       component => $component,
	       summary => $summary,
	       description => $description,
	       version => (($version ne "") ? $version : 'unspecified')
	      );
    if ($severity ne "") {
      $bug{severity} = $severity;
    }
    if ($priority ne "") {
      $bug{priority} = $priority;
    }
    if ($milestone ne "") {
      $bug{target_milestone} = $milestone;
    }
    if ($os ne "") {
      $bug{op_sys} = $os;
    }
    if ($platform ne "") {
      $bug{platform} = $platform;
    }
    push @bugs, \%bug;
    # save dependencies for later
    push @parents, ($blocks ne "") ? $blocks : "";
    push @subtasks, ($depends_on ne "") ? $depends_on : "";
  }
}
close $fh;
if (not ($#bugs >= 0)) {
  print "No valid new bugs for importing found in \"".$filename."\".\n";
  exit;
}
print "Found ".($#bugs + 1)." valid new bugs in \"".$filename."\".\n";

###
#  instantiate REST client
#
my $client = REST::Client->new();
my $request;
my $request_json;
my $response_json;
my $response;
my $bugzilla = prompt('x', 'Enter Bugzilla server URL:', '', '');
$client->setHost($bugzilla);
$client->addHeader('Accept', 'application/json');
$client->addHeader('Content-Type', 'application/json');
$client->setFollow(1);

###
#  check Bugzilla version
#
$client->GET('/rest/version');
$response_json = $client->responseContent();
if ($client->responseCode() != 200) {
  print $bugzilla." responded to with HTTP status ".$client->responseCode()."\n";
  print "It seems your server doesn't support the REST interface, or is not version 5.0 or newer.\n";
  print $response_json."\n";
  exit;
}
$response = decode_json $response_json;
print "Good news: ".$bugzilla." is version ".$response->{'version'}."\n";

###
# request API key from user
# https://bugzilla.readthedocs.io/en/latest/using/preferences.html#api-keys
#
print "You can set up an API key by using the API Keys tab in Bugzilla's Preferences pages.\n";
my $api_key = prompt('p', 'Enter the API key to use:', '', '',);
print "\n";
my %auth_token = (
		  api_key => $api_key,
		 );
$client->GET('/rest/logout'.$client->buildQuery(%auth_token));
$response_json = $client->responseContent();
if ($client->responseCode() != 200) {
  print $bugzilla." responded to with HTTP status ".$client->responseCode()."\n";
  print "Did you use a valid API key?\n";
  exit;
}

###
#  file new bugs
#
my @bugids;
my $bug_json;
for my $i (0 .. $#bugs) {
  print "New issue [".($i + 1)."] ";
  $bug_json = encode_json $bugs[$i];
  $client->request('POST', '/rest/bug'.$client->buildQuery(%auth_token), $bug_json);
  $response_json = $client->responseContent();
  if ($client->responseCode() != 200) {
    print $bugzilla." responded to with HTTP status ".$client->responseCode()."\n";
    print "Adding a new bug failed.\n";
    print $response_json."\n";
    exit;
  }
  $response = decode_json $response_json;
  my $bugid = $response->{'id'};
  print "filed as bug ".$bugid."\n";
  push @bugids, $bugid;
}

###
#  set the parent/children of the new bugs (cannot set on creation, hence do an update)
#
print "Setting dependencies...\n";
for my $i (0 .. $#bugids) {
  my $update = {
		ids => [ $bugids[$i] ],
		blocks => {
			   add => [ split(',', $parents[$i]) ],
			  },
		depends_on => {
			   add => [ split(',', $subtasks[$i]) ],
			  },
	       };
  my $update_json = encode_json $update;
  $client->request('PUT', '/rest/bug/'.$bugids[0].$client->buildQuery(%auth_token), $update_json);
  $response_json = $client->responseContent();
    if ($client->responseCode() != 200) {
    print $bugzilla." responded to with HTTP status ".$client->responseCode()."\n";
    print "Setting dependencies failed.\n";
    print $response_json."\n";
    exit;
  }
  print "Added dependencies for bug [".$bugids[$i]."]\n";
}
