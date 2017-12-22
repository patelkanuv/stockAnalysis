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
use Text::CSV::Simple;

my $csv_writer = Class::CSV->new(
    fields          => [qw/Name code myView DebtToEqity CurrentRato CAGR_1 CAGR_2 CAGR_3 CAGR_4 CAGR_5 CAGR_6/],
    line_separator  => "\r\n"
);

$csv_writer->add_line([ 'Name', 'Code', 'MyOpinion', 'DebtToEqity', 'CurrentRato', 'CAGR 1 Year', 
                        'CAGR 2 Year', 'CAGR 3 Year','CAGR 4 Year', 'CAGR 5 Year', 'CAGR 6 Year' ]);
my @raw_data    = get_records();

my $cnt = 1;
foreach my $rec (@raw_data) {
    next if  $rec->{ 'code' }  =~ /\D/;
    #next if  $rec->{ 'name' }  !~ /Aditya Birla Money/;
    try {
        my $record  = get_content($rec->{ 'code' });
        add_record($csv_writer, $record, $rec->{ 'code' });
        sleep(1);
    }
    catch {
        try {
            sleep(4);
            print $_, "Something went wrong while fetching ", $rec->{ 'name' }, "\n";
            my $record  = get_content($rec->{ 'code' });
            add_record($csv_writer, $record, $rec->{ 'code' });
        };
    };  
}

open(CFILE,">","Reports/stock_cagr_report.csv");
print CFILE $csv_writer->string();   
close CFILE;

sub add_record { 
    my ($csv_writer, $record, $code ) = @_;
    
    print $record->{'name'}, " ", $record->{'myView'} || "open", " ", $record->{'cagr_1'}, " ", $record->{'cagr_3'}," ", $record->{'cagr_5'},"\n";
    $csv_writer->add_line([
            $record->{'name'},
            $code, 
            $record->{'myView'},
            $record->{'DebtToEqity'},
            $record->{'CurrentRato'},
            $record->{'cagr_1'} || '-',
            $record->{'cagr_2'} || '-',
            $record->{'cagr_3'} || '-',
            $record->{'cagr_4'} || '-',
            $record->{'cagr_5'} || '-',
            $record->{'cagr_6'} || '-'
        ]);
}

sub get_content {
    my ($code) = @_;
    
    my $mech = WWW::Mechanize->new();
    my $response    = $mech->get("https://www.valueresearchonline.com");
    #print Dumper $response->decoded_content;
    sleep(5);
    $response    = $mech->get("https://www.valueresearchonline.com/stocks/Finnance_Annual.asp?code=".$code);

    if ($response->is_success) {
        return parse_response($response, $code);        
    }
    else {
        die $response->status_line;
    }
}


sub parse_response {
    my ($response, $code)  = @_;
    
    my %stock_data;
    my $tree= HTML::TreeBuilder::XPath->new;
    $tree->parse($response->decoded_content);
    
    my $stock_name  = $tree->findvalue( '//h1[@class="stock-tittle"]');

    my (@stock_performance, @stock_perform_value, @stock_perform_debt, @stock_perform_current_ratio);
    try {
        my @data    = $tree->findnodes( '/html/body//div[@class="pull-left sectionHead"]/table/tr');
        my $rows    = scalar(@data);
        @stock_performance      
            = $tree->findnodes( '/html/body//div[@class="pull-left sectionHead"]/table/tr')->[0]->findnodes('./th');
        
        foreach my $key(1..$rows) {
            try {
                my @stock_value 
                    = $tree->findnodes( '/html/body//div[@class="pull-left sectionHead"]/table/tr')->[$key]->findnodes('./td');
                if ($stock_value[0]->findvalue('.') =~ /Total Income/) {
                    @stock_perform_value = @stock_value;   
                }
                elsif($stock_value[0]->findvalue('.') =~ /Debt to Equity/) {
                    @stock_perform_debt = @stock_value;    
                }
                elsif($stock_value[0]->findvalue('.') =~ /Current Ratio/) {
                    @stock_perform_current_ratio = @stock_value;    
                }
            };        
        }    
    }
    catch {
        print $_, "\n";
        my @data    = $tree->findnodes( '/html/body//div[@class="pull-left sectionHead margin_top"]/table/tr');
        my $rows    = scalar(@data);
        @stock_performance      
            = $tree->findnodes( '/html/body//div[@class="pull-left sectionHead margin_top"]/table/tr')->[0]->findnodes('./th');

        foreach my $key(1..$rows) {
            try {
                my @stock_value 
                    = $tree->findnodes( '/html/body//div[@class="pull-left sectionHead margin_top"]/table/tr')->[$key]->findnodes('./td');
                if ($stock_value[0]->findvalue('.') =~ /Total Income/) {
                    @stock_perform_value = @stock_value;   
                }
                elsif($stock_value[0]->findvalue('.') =~ /Debt to Equity/) {
                    @stock_perform_debt = @stock_value;    
                }
                elsif($stock_value[0]->findvalue('.') =~ /Current Ratio/) {
                    @stock_perform_current_ratio = @stock_value;    
                }
            };        
        }
           
    };
 
    my (@performance_headers, @income_performance_value, @debt_to_equity_value, @current_ratio_value);
    my $index   = scalar(@stock_performance) -1;    
    foreach my $key (0..$index) {
        push(@performance_headers, $stock_performance[$key]->findvalue('.'));
        push(@income_performance_value, $stock_perform_value[$key]->findvalue('.'));
        try {
            push(@debt_to_equity_value, $stock_perform_debt[$key]->findvalue('.'));
            push(@current_ratio_value, $stock_perform_current_ratio[$key]->findvalue('.'));
        };    
    }

    my ($years, $start, $end)   = (0, 0, 0);
    my $idx = ($performance_headers[1]  eq 'TTM') ? 2 : 1;
    $end    = decommify($income_performance_value[$idx]);

    for(my $i = 1; $i < scalar(@performance_headers); $i++ ) {
        next if $performance_headers[$i]  eq 'TTM';
        next if $income_performance_value[$i]  =~ /-/;
        next if decommify($income_performance_value[$i])  == 0;

        $start  = decommify($income_performance_value[$i]);
        $stock_data{ "cagr_".$years }   = calc_cagr($start, $end, $years) if $years > 0;
        $years++;        
    }

    $stock_name =~ s/&/ and /;
    $stock_data{ 'DebtToEqity' }    = decommify($debt_to_equity_value[$idx]);
    $stock_data{ 'CurrentRato' }    = decommify($current_ratio_value[$idx]);
    $stock_data{ 'myView' }         = get_my_opinion(\%stock_data);
    $stock_data{ 'name' }           = $stock_name;
    $stock_data{ 'code' }           = $code;
    $stock_data{ 'start' }          = $start;
    $stock_data{ 'end' }            = $end;
    $stock_data{ 'years' }          = $years;
    
    
#    print Dumper \%stock_data, \@performance_headers, \@income_performance_value;
    return \%stock_data;
}

sub get_my_opinion {
    my ($stock_data)    = @_;
    
    return "" if !defined $stock_data->{'cagr_1'};
    if (defined $stock_data->{'DebtToEqity'} && defined $stock_data->{'CurrentRato'}) {         
        return "" if $stock_data->{'CurrentRato'} < 1.5 && $stock_data->{'DebtToEqity'} > 1;
    }
    if($stock_data->{'cagr_1'} >= 10 && $stock_data->{'cagr_3'} >= 10 && $stock_data->{'cagr_5'} >= 10) {
        return "YES";
    }
    elsif(($stock_data->{'cagr_1'} >= 10 && $stock_data->{'cagr_3'} >= 10) 
         || ($stock_data->{'cagr_1'} >= 10 && $stock_data->{'cagr_2'} >= 10)
         || ($stock_data->{'cagr_2'} >= 10 && $stock_data->{'cagr_3'} >= 10)) {
        return "YES";
    }
    elsif(($stock_data->{'cagr_3'} >= 10 && $stock_data->{'cagr_5'} >= 10)
          || ($stock_data->{'cagr_1'} >= 8 && $stock_data->{'cagr_5'} >= 10)) {
        return "Explore";
    }
    elsif(($stock_data->{'cagr_1'} >= 15 && $stock_data->{'cagr_3'} >= 8) 
         || ($stock_data->{'cagr_3'} >= 8 && $stock_data->{'cagr_5'} >= 12)) {
        return "Explore";
    }
    elsif($stock_data->{'cagr_1'} >= 20 ) {
        return "Explore";
    }
    return "";
}

sub calc_cagr {
    my ($start, $end, $years)   = @_;

    my $cagr    = ((($end/$start)**(1/$years))-1)*100;
    return sprintf("%.2f", $cagr);
}

sub get_records {
    my $parser = Text::CSV::Simple->new;
    $parser->field_map(qw/name code industry investment/);
    my @data = $parser->read_file("raw_data/Stock Analysis - Raw Data.csv");

    return @data;
}

sub decommify { 
    my ( $number ) = @_;

    $number =~ tr/,//d;
    return $number
}
