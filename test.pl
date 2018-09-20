#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use Time::HiRes qw (tv_interval gettimeofday);
use Try::Tiny;
use Class::CSV;
use Data::Dumper;
use WWW::Mechanize;
use HTML::TreeBuilder::XPath;
use Text::CSV;
use Text::CSV::Simple;

my @raw_data1    = get_records();
my @raw_data2    = get_records_final();
my $count = 0;
my %records;
foreach my $rec (@raw_data1) {
    next if  $rec->{ 'code' }  =~ /\D/;
    $records{ $rec->{ 'code' } }{'Name1'}   = $rec->{ 'name' };
}

foreach my $rec (@raw_data2) {
    next if  $rec->{ 'Code' }  =~ /\D/;
    $records{ $rec->{ 'Code' } }{'Name2'}   = $rec->{ 'Name' };
}

foreach my $key (keys %records) {
    if($records{ $key }{'Name1'} ne $records{ $key }{'Name2'}) {
        print "$key have Name1 :  $records{ $key }{'Name1'} and Name2: $records{ $key }{'Name2'}\n";  
    }
}    

sub get_records {
    my $parser = Text::CSV::Simple->new;
    $parser->field_map(qw/name code industry investment/);
    my @data = $parser->read_file("raw_data/Stock Analysis - Raw Data.csv");

    return @data;
}

sub get_records_final {
    my $parser = Text::CSV::Simple->new;
    $parser->field_map(qw/Name Code Industry MyView price Change Change% Volume PE PB Cap Revenue Profit NetMargin ROE 1M 3M 1Y 3Y 5Y 10Y/);
    my @data = $parser->read_file("Reports/stock_report.csv");

    return @data;
}
