#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::Util;
use Mojo::JSON;

use Encode;
use File::Spec;
use Data::ICal;
use Data::ICal::Entry::Event;

app->config(hypnotoad => {listen => ['http://*:3000'], workers => 20});
app->types->type(ics => 'text/calendar; charset=utf-8');

helper read_json => sub {
  my ($c, $file) = @_;
  open my $fh, '<', $file or return undef;
  my $content = do { local $/; <$fh> };
  close $fh;
  my $json = Mojo::JSON->new;
  return $json->decode($content);
};

helper get_area => sub {
  my ($c, $state, $city) = @_;
  my $file = File::Spec->catfile('json', $state, $city, 'area.json') or return undef;
  return $c->read_json($file)
};

helper get_data => sub {
  my ($c, $state, $city, $first, $second) = @_;
  my $meta = $c->get_area($state, $city) or return undef;
  my $file = File::Spec->catfile('json', $state, $city, $meta->{$first}->{$second});
  return $c->read_json($file)
};

get '/' => sub {
  my $c = shift;
  my ($state, $city) = ('北海道', '札幌市');
  my $area = $c->get_area($state, $city) or return $c->render_not_found;
  $c->stash(state => $state, city  => $city, area  => $area, ver => 1);
  $c->render('index');
};

# /gcweb/北海道/札幌市/中央区/中島公園
get '/ics/:state/:city/:first/:second' => sub {
  my $c = shift;
  my $r = $c->get_data(
            $c->param('state'), 
            $c->param('city'),
            $c->param('first'),
            $c->param('second')
          ) or return $c->render_not_found;
  my $ret = $r->{data};

  my $ical = Data::ICal->new;
  my $calname = sprintf('ごみの日 %s%s%s - %s',
                  $c->param('state'),
                  $c->param('city'),
                  $c->param('first'),
                  $c->param('second')
                );

  $ical->add_properties(
    prodid          => 'MYAPP',
    'X-WR-CALNAME'  => $calname,
    'X-WR-CALDESC'  => $calname,
    'X-WR-TIMEZONE' => "Asia/Tokyo",
  );

  foreach my $type (keys %$ret) {
    foreach my $date (@{$ret->{$type}}) {
      $date =~ s/\-//g;
      my $ev = Data::ICal::Entry::Event->new;
      $ev->add_properties(
        summary     => $type,
        dtstart     => [$date, {VALUE => 'DATE'}],
        dtend       => [$date, {VALUE => 'DATE'}],
        description => $type,
      );
      $ical->add_entry($ev);
    }
  }
  $c->render(data => encode_utf8($ical->as_string), format => 'ics');
};

# /gcweb/北海道/札幌市/中央区/中島公園/燃やせるごみ
get '/ics/:state/:city/:first/:second/:third' => sub {
  my $c = shift;
  my $r = $c->get_data(
            $c->param('state'),
            $c->param('city'),
            $c->param('first'),
            $c->param('second')
          ) or return $c->render_not_found;
  my $ret = $r->{data}->{$c->param('third')};

  my $ical = Data::ICal->new;
  my $calname = sprintf('ごみの日(%s) %s%s%s - %s',
                  $c->param('third'),
                  $c->param('state'),
                  $c->param('city'),
                  $c->param('first'),
                  $c->param('second')
                );
  $ical->add_properties(
    prodid          => 'MYAPP',
    'X-WR-CALNAME'  => $calname,
    'X-WR-CALDESC'  => $calname,
    'X-WR-TIMEZONE' => "Asia/Tokyo",
  );

  foreach my $date (@$ret) {
    $date =~ s/\-//g;
    my $ev = Data::ICal::Entry::Event->new;
    $ev->add_properties(
      summary     => $c->param('third'),
      dtstart     => [$date, {VALUE => 'DATE'}],
      dtend       => [$date, {VALUE => 'DATE'}],
      description => $c->param('third'),
    );
    $ical->add_entry($ev);
  }
  $c->render(data => encode_utf8($ical->as_string), format => 'ics');
};

app->start;
__DATA__

@@ index.html.ep
<!DOCTYPE html>
<html lang="en">
<head>
  <meta http-equiv="content-type" content="text/html; charset=UTF-8">
  <meta charset="utf-8">
  <title>札幌市のごみ収集カレンダー ical版</title>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <link href="//maxcdn.bootstrapcdn.com/bootstrap/3.2.0/css/bootstrap.min.css" rel="stylesheet">
  <link href="//maxcdn.bootstrapcdn.com/font-awesome/4.1.0/css/font-awesome.min.css" rel="stylesheet">
  <!--[if lt IE 9]>
    <script src="//html5shim.googlecode.com/svn/trunk/html5.js"></script>
  <![endif]-->
  <link href="css/styles.css" rel="stylesheet">
</head>
<body>
  <div class="wrapper">
    <div class="box">
      <div class="row">
        
        <!-- sidebar -->
        <div class="column col-sm-3" id="sidebar">
          <a class="logo" href="#top"><span class="glyphicon glyphicon-trash"></span></a>
          <ul class="nav">
            % {
            %   my $i = 0;
            %   foreach my $ward (sort keys %$area) {
            <li><a href="#ward_<%= $i++ %>"><%= $ward %></a></li>
            %   }
            % }
          </ul>
          <ul class="nav hidden-xs" id="sidebar-footer">
              <h3>gomical <a href="https://github.com/syachi/gomical"><i class="fa fa-github"></i></a></h3>
              <a href="http://gomical.net">http://gomical.net</a>
          </ul>
        </div>
        <!-- /sidebar -->
      
        <!-- main -->
        <div class="column col-sm-9" id="main">
          <div class="padding" id="top">
            <div class="full col-sm-9">
  
              <div class="col-sm-12">
                <h1>札幌市のごみ収集日カレンダー<small> iCal版</small></h1>
                <p>札幌市のごみ収集日をical形式で配布しています。</p>
              </div>

              <div class="col-sm-12">
                <div class="page-header text-muted" id="templates">
                  エリア
                </div>
              </div>
            
              <div class="row">
                <div class="col-sm-12">
                  <p>お住まいの地域を選択してください</p>
                  <p class="type">
                  % {
                  %   my $i = 0;
                  %   foreach my $ward (sort keys %$area) {
                  <a href="#ward_<%= $i++ %>" class="btn btn-default btn-sm" role="button"><%= $ward %></a>
                  %   }
                  % }
                  </p>
                </div>
              </div>
              <hr>
            
              % {
              %   my $i = 0;
              %   foreach my $ward (sort keys %$area) {
              <div class="col-sm-12" id="ward_<%= $i++ %>">   
                <div class="page-header text-muted">
                <%= $ward %>
                </div> 
              </div>
              %     foreach my $street (sort keys %{$area->{$ward}}) {
              <div class="row">    
                <div class="col-sm-12">
                  <h3><%= $street %></h3>
                  <p class="type">
                    <a href="ics/<%= $state %>/<%= $city %>/<%= $ward %>/<%= $street %>?<%= $ver %>" class="btn btn-default btn-sm" role="button">すべての収集日</a>
                    <a href="ics/<%= $state %>/<%= $city %>/<%= $ward %>/<%= $street %>/燃やせるごみ?<%= $ver %>" class="btn btn-default btn-sm" role="button">燃やせるごみ</a>
                    <a href="ics/<%= $state %>/<%= $city %>/<%= $ward %>/<%= $street %>/燃やせないごみ?<%= $ver %>" class="btn btn-default btn-sm" role="button">燃やせないごみ</a>
                    <a href="ics/<%= $state %>/<%= $city %>/<%= $ward %>/<%= $street %>/容器包装プラスチック?<%= $ver %>" class="btn btn-default btn-sm" role="button">容器包装プラスチック</a>
                    <a href="ics/<%= $state %>/<%= $city %>/<%= $ward %>/<%= $street %>/びん・缶・ペットボトル?<%= $ver %>" class="btn btn-default btn-sm" role="button">びん・缶・ペットボトル</a>
                    <a href="ics/<%= $state %>/<%= $city %>/<%= $ward %>/<%= $street %>/雑がみ?<%= $ver %>" class="btn btn-default btn-sm" role="button">雑がみ</a>
                    <a href="ics/<%= $state %>/<%= $city %>/<%= $ward %>/<%= $street %>/枝・葉・草?<%= $ver %>" class="btn btn-default btn-sm" role="button">枝・葉・草</a>
                  </p>
                </div>
              </div>
              <hr>
              %     }
              %   }
              % }
            
            </div><!-- /col-9 -->
          </div><!-- /padding -->
        </div>
        <!-- /main -->
      </div>
    </div>
  </div>

  <!-- script references -->
  <script src="//ajax.googleapis.com/ajax/libs/jquery/2.0.2/jquery.min.js"></script>
  <script src="//maxcdn.bootstrapcdn.com/bootstrap/3.2.0/js/bootstrap.min.js"></script>
  <script>
    (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
    (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
    m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
    })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
    ga('create', 'UA-54157019-1', 'auto');
    ga('send', 'pageview');
  </script>

</body>
</html>
