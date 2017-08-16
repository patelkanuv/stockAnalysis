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


my @raw_data    = get_raw_data();
my @price_data  = get_stock_price_records();
my @cagr_data   = get_stock_cagr_records();

my %final_view;

foreach my $rec (@raw_data) {
    $final_view{ $rec->{ 'Code' } }   = $rec;    
}

foreach my $rec (@price_data) {
    $final_view{ $rec->{ 'Code' } }{ 'price_view' } = $rec->{ 'MyView' };    
}

foreach my $rec (@cagr_data) {
    $final_view{ $rec->{ 'Code' } }{ 'cagr_view'}   = $rec->{ 'MyView' };    
    $final_view{ $rec->{ 'Code' } }{ 'MyView'}      = get_final_view($rec->{ 'MyView' }, 
                                                        $final_view{ $rec->{ 'Code' } }{ 'price_view' });    
}

write_data(\%final_view);

sub write_data {
    my ($data)  = @_;
    
    my $csv_writer = Class::CSV->new(
        fields          => [qw/Name code industry price_view cagr_view final_view investment/],
        line_separator  => "\r\n"
    );

    $csv_writer->add_line([ 'Name', 'Code', 'Industry', 'PriceView', 'CAGRView', 'FinalView', 'Investment']);
                        
    foreach my $code (sort { $data->{$a}{'Name'} cmp $data->{$b}{'Name'} } keys %{$data}) {
        next if $code =~ /\D/;
        $csv_writer->add_line([ 
            $data->{$code}{'Name'}, 
            $data->{$code}{'Code'}, 
            $data->{$code}{'industry'}, 
            $data->{$code}{'price_view'}, 
            $data->{$code}{'cagr_view'}, 
            $data->{$code}{'MyView'}, 
            $data->{$code}{'investment'}
        ]);
    }
    
    open(CFILE,">","Reports/stock_myopinion_report.csv");
    print CFILE $csv_writer->string();   
    close CFILE;
}

sub get_final_view {
    my ($cagr_view, $price_view)    = @_;
    
    if($cagr_view eq 'YES' && ($price_view eq 'YES' || $price_view eq 'Explore')) {
        return 'YES';
    }
    elsif($cagr_view eq 'Explore' && ($price_view eq 'YES' || $price_view eq 'Explore')) {
        return 'Explore';
    }
    elsif($cagr_view eq 'YES' || $price_view eq 'YES') {
        return 'Explore';    
    }
    
    return '';
}


sub get_raw_data {
    my $parser = Text::CSV::Simple->new;
    $parser->field_map(qw/Name Code industry investment/);
    my @data = $parser->read_file("raw_data/Stock Analysis - Raw Data.csv");

    return @data;
}

sub get_stock_price_records {
    my $parser = Text::CSV::Simple->new();
    $parser->field_map(qw/Name Code industry MyView price change change_perc volume PE 
                          PB Cap Revenue Profit NetMargin ROE 1M 3M 1Y 3Y 5Y 10Y/);
    my @data = $parser->read_file("Reports/stock_report.csv");
    
    return @data;    
}

sub get_stock_cagr_records {
    my $parser = Text::CSV::Simple->new();
    $parser->field_map(qw/Name Code MyView CAGR1 CAGR2 CAGR3 CAGR4 CAGR5 CAGR6/);
    my @data = $parser->read_file("Reports/stock_cagr_report.csv");
    
    return @data;    
}
