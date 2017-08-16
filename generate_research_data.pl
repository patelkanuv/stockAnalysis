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

my $csv = Text::CSV->new();

my $csv_writer = Class::CSV->new(
    fields          => [
        qw/Name Code Industry MyView price Change Change% Volume PE PB Cap Revenue Profit NetMargin ROE 1M 3M 1Y 3Y 5Y 10Y/ ],
    line_separator  => "\r\n"
);

$csv_writer->add_line([ 
    'Name', 'Code', 'Industry', 'myOpinion','Price', 'Change', 'Change%', 'Volume','PE', 'PB', 'Market cap', 'Revenue', 'Profit',
    'NetMargin', 'ROE', '1M','3M','1Y','3Y','5Y','10Y'
]);

my @raw_data    = get_records();
my $count = 0;
foreach my $rec (@raw_data) {
    next if  $rec->{ 'code' }  =~ /\D/;
    $count++;   
    try {
        my $record  = get_content($rec->{ 'name'}, $rec->{ 'code' }, $rec->{ 'industry'});
        add_record($csv_writer, $record, $rec->{ 'code' });
    }
    catch {
        sleep(5);
        print $_, "Something went wrong while fetching ", $rec->{ 'name' }, "\n";
        my $record  = get_content($rec->{ 'name'}, $rec->{ 'code' }, $rec->{ 'industry'}, $rec->{ 'myOpinion'});
        add_record($csv_writer, $record, $rec->{ 'code' });
    };

    #last if $count == 100;   
}

#open(CFILE,">>","stock_report.csv");
open(CFILE,">","Reports/stock_report.csv");
print CFILE $csv_writer->string();   
close CFILE;

sub add_record { 
    my ($csv_writer, $record, $code) = @_;
    
    print $record->{'name'}, "\n";
    
    $csv_writer->add_line([
            $record->{'name'},
            $code, 
            $record->{'industry'},
            $record->{'my_view'},
            $record->{'stock_price'},
            $record->{'price_change'},
            $record->{'change_per'},
            $record->{'volume'},
            $record->{'PE'},
            $record->{'PB'},
            $record->{'market_cap'},
            $record->{'stock_revenue'},
            $record->{'net_profit'},
            $record->{'net_margin'},
            $record->{'ROE'},
            $record->{'performance_1M'},
            $record->{'performance_3M'},
            $record->{'performance_1Y'},
            $record->{'performance_3Y'},
            $record->{'performance_5Y'},
            $record->{'performance_10Y'},
        ]);
}

sub get_content {
    my ($stock_name, $stock_code, $stock_ind) = @_;
    
    my $mech = WWW::Mechanize->new();
    my $response    = $mech->get("https://www.valueresearchonline.com");
    #print Dumper $response->decoded_content;
    sleep(5);
    my $stock_url   = "https://www.valueresearchonline.com/stocks/snapshot.asp?code=".$stock_code;
    $response    = $mech->get($stock_url);

    if ($response->is_success) {
        return parse_response($response, $stock_ind);        
    }
    else {
        die $response->status_line;
    }
}

sub parse_response {
    my ($response, $stock_ind)  = @_;
    
    my %stock_data;
    my $tree= HTML::TreeBuilder::XPath->new;
    $tree->parse($response->decoded_content);
      
    my $stock_name  = $tree->findvalue( '//h1[@class="stock-tittle"]');
    my $stock_val   = $tree->findvalue( '//div[@id="stockPrice"]//tr[@class="daily-stock-price"]/td');
    my @stock_value  = split(" ", $stock_val);
    
    $stock_data{ 'stock_price'} = $stock_value[1];

    my @daily_performance   = $tree->findnodes( '/html/body//div[@id="collapseDetails"]/table/tr')->[0]->findnodes('./td');
    my @daily_performance_value;
    foreach my $node (@daily_performance) {
        push(@daily_performance_value, $node->findvalue('.'));
    }
    
    $stock_data{ 'price_change' }   = $daily_performance_value[2];
    $stock_data{ 'change_per' }     = $daily_performance_value[3];
    $stock_data{ 'volume' }         = $daily_performance_value[6];
        
    try {
         my @stock_performance   = $tree->findnodes( '/html/body//div[@class="pull-left sectionHead"][@id="performance"]/table/tr')->[1]->findnodes('./td');
        my @performance_value;
        foreach my $node (@stock_performance) {
            push(@performance_value, $node->findvalue('.'));
        }

        $stock_data{ 'performance_1M' } = $performance_value[2];
        $stock_data{ 'performance_3M' } = $performance_value[3];
        $stock_data{ 'performance_1Y' } = $performance_value[4];
        $stock_data{ 'performance_3Y' } = $performance_value[5];
        $stock_data{ 'performance_5Y' } = $performance_value[6];
        $stock_data{ 'performance_10Y' } = $performance_value[7];
    }
    catch {
        print "Unable to find performance of $stock_name\n";
        $stock_data{ 'performance_1M' } = '-';
        $stock_data{ 'performance_3M' } = '-';
        $stock_data{ 'performance_1Y' } = '-';
        $stock_data{ 'performance_3Y' } = '-';
        $stock_data{ 'performance_5Y' } = '-';
        $stock_data{ 'performance_10Y' } = '-';
    };
    my @peer_performance   = $tree->findnodes( '/html/body//div[@id="peer-comparison"]/div[@class="pull-left sectionHead"]/table/tr')->[1]->findnodes('./td');

    my @peer_value;
    foreach my $node (@peer_performance) {
        push(@peer_value, $node->findvalue('.'));
    }

    $peer_value[0] =~ s/^\s+|\s+$//g;
    $peer_value[0] =~ s/&/ and /g;
    
    $stock_data{ 'name' }           = $peer_value[0];
    $stock_data{ 'industry' }       = $stock_ind;
    $stock_data{ 'market_cap' }     = $peer_value[1];
    $stock_data{ 'stock_revenue' }  = $peer_value[2];
    $stock_data{ 'net_profit' }     = $peer_value[3];
    $stock_data{ 'net_margin' }     = $peer_value[4];
    $stock_data{ 'ROE' }            = $peer_value[5];
    $stock_data{ 'PB' }             = $peer_value[6];
    $stock_data{ 'PE' }             = $peer_value[7];
    $stock_data{ 'my_view' }        = get_my_opinion(\%stock_data);

    return \%stock_data;
}

sub get_records {
    my $parser = Text::CSV::Simple->new;
    $parser->field_map(qw/name code industry investment/);
    my @data = $parser->read_file("raw_data/Stock Analysis - Raw Data.csv");

    return @data;
}

sub get_my_opinion {
    my ($stock_data)    = @_;
       
    if($stock_data->{'performance_1Y'} >= 10 && $stock_data->{'performance_3Y'} >= 10 
       && $stock_data->{'performance_5Y'} >= 10 && $stock_data->{'performance_10Y'} >= 10
       && $stock_data->{'PB'} <= 4 && $stock_data->{'PE'} <= 40) {
        return "YES";
    }
    elsif($stock_data->{'performance_3Y'} >= 10 && $stock_data->{'performance_5Y'} >= 15 
       && $stock_data->{'PB'} <= 4 && $stock_data->{'PE'} <= 40) {
        return "YES";
    }
    elsif($stock_data->{'performance_3Y'} >= 15 && $stock_data->{'performance_5Y'} >= 10 
          && $stock_data->{'PB'} <= 4 && $stock_data->{'PE'} <= 40) {
        return "YES";
    }
    elsif($stock_data->{'performance_3Y'} >= 15 && $stock_data->{'performance_5Y'} >= 15 
          && $stock_data->{'PB'} <= 5.5 && $stock_data->{'PE'} <= 30) {
        return "YES";
    }
    elsif($stock_data->{'performance_3Y'} >= 10 && $stock_data->{'performance_5Y'} >= 15 
          && $stock_data->{'PB'} <= 5 && $stock_data->{'industry'} eq 'Bank/Finance') {
        return "YES";
    }
    elsif($stock_data->{'performance_5Y'} >= 15 && $stock_data->{'performance_10Y'} >= 15 
          && $stock_data->{'PB'} <= 5 && $stock_data->{'industry'} eq 'Bank/Finance') {
        return "YES";
    }
    elsif($stock_data->{'net_margin'} >= 4 && $stock_data->{'industry'} eq 'Bank/Finance') {
        return "YES";
    }
    elsif($stock_data->{'net_margin'} >= 15 
          && $stock_data->{'PB'} <= 5 && $stock_data->{'PE'} <= 25) {
        return "YES";
    }
    elsif($stock_data->{'net_margin'} >= 20) {
        return "YES";
    }
    elsif($stock_data->{'performance_1Y'} >= 30 && $stock_data->{'performance_3Y'} >= 25 
          && $stock_data->{'net_margin'} >= 12 && $stock_data->{'PE'} <= 40) {
        return "YES";
    }
    elsif($stock_data->{'performance_3Y'} >= 20 && $stock_data->{'performance_5Y'} >= 15 
          && $stock_data->{'net_margin'} >= 8 ) {
        return "Explore";
    }
    elsif($stock_data->{'performance_3Y'} >= 10 
       && $stock_data->{'performance_5Y'} >= 15 && $stock_data->{'performance_10Y'} >= 15) {
        return "Explore";    
    }
    elsif($stock_data->{'performance_3Y'} >= 15 
       && $stock_data->{'performance_5Y'} >= 15 && $stock_data->{'performance_10Y'} >= 10) {
        return "Explore";    
    }
    
    return "";
}
