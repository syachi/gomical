#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use CHI;
use WWW::Mechanize::Cached;
use Date::Manip;
use JSON;
use Digest::MD5;
use DDP;

binmode(STDOUT, ":utf8");
$|++;

# 曜日名変換(日->英)
my $day = {
    '月' => 'Monday',
    '火' => 'Tuesday',
    '水' => 'Wednesday',
    '木' => 'Thursday',
    '金' => 'Friday',
    '土' => 'Saturday',
    '日' => 'Sunday',
};

# 月名変換(数->英)
my $mon = {
    1  => 'January',
    2  => 'February',
    3  => 'March',
    4  => 'April',
    5  => 'May',
    6  => 'June',
    7  => 'July',
    8  => 'August',
    9  => 'September',
    10 => 'October',
    11 => 'November',
    12 => 'December',
};

my $output_dir = 'json/北海道/札幌市';

# JSONで結果を出力する
sub main
{
    my $interval = 1; # 秒

    my $retatastore = {};
    #my $cache = CHI->new(driver => 'Memory', datastore => $retatastore); # memory cache
    my $cache = CHI->new(driver => 'File', root_dir => '/tmp/my_cache'); # file cache

    # トップページを取得
    my $w = WWW::Mechanize::Cached->new(autocheck => 0, cache => $cache);
    $w->get('http://www.city.sapporo.jp/seiso/kaisyu/yomiage/index.html');

    my $json = new JSON;
    $json->pretty;

    my $data = {};
    my $ret = {};

    # トップページに含まれる区のリンク
    my @wards = $w->find_all_links(url_regex => qr@/yomiage/[0-9]+.+\.html$@);
    foreach my $ward (@wards) {

        # 区のページを取得
        sleep $interval if !$w->is_cached();
        $w->get($ward->url_abs());

        # 区のページに含まれる「通り」のリンクを抽出(同じページのリンクが複数含まれる)
        my @streets = $w->find_all_links(url_regex => qr@/carender/[0-9]+.+\.html$@);
        foreach my $street (@streets) {

            printf "=> %s - %s\n", $ward->text(), $street->text();

            # md5で出力するファイル名を決める
            my $filename = Digest::MD5::md5_hex($street->url_abs) . '.json';

            # 既に読み込み済みのページの場合はスキップする
            if (not defined $data->{$street->url_abs}) {

                # 通りのページを取得
                sleep $interval if !$w->is_cached();
                $w->get($street->url_abs());

                # HTMLをparseした結果を取得する
                $data->{$street->url_abs} = parser($w->content()) or die;
                my $zone = {};
                $zone->{data}   = parser($w->content()) or die;
                $zone->{url}    = $street->url_abs->as_string;

                # 収集日をファイルに出力する
                open my $fh, ">:utf8", $output_dir . '/' .$filename or die $@;
                print $fh $json->encode($zone);
                close $fh;
            }
            $ret->{$ward->text()}->{$street->text()} = $filename;
        }
    }

    # 地区とファイル名の関係をファイルに出力する
    open my $fh, ">:utf8", $output_dir . '/area.json' or die $@;
    print $fh $json->encode($ret);
    close $fh;
}

# 日付の形式を統一する
sub date_format
{
    my $days = shift;

    my @ret = ();
    foreach my $day (@$days) {
        my $dtstr = UnixDate($day, "%Y-%m-%d");

        # 音声読み上げページの方が間違っているので対処。この日は集取は休み。
        next if $dtstr =~ m/2015-12-30/;
        next if $dtstr =~ m/2015-12-31/;
        next if $dtstr =~ m/2016-01-01/;

        push @ret, $dtstr;
    }
    return @ret;
}

# 文章をparseして日付を取得する
sub parser
{
    my $content = shift;

    my $ret = {
        '燃やせないごみ'         => [],
        '枝・葉・草'             => [],
        'びん・缶・ペットボトル' => [],
        '容器包装プラスチック'   => [],
        '雑がみ'                 => [],
        '燃やせるごみ'           => [],
    };

    my @matches = ($content =~ m@(平成.+の収集日です。.*?)(<.+?>|&nbsp;)@g);
    foreach my $match (@matches) {

        $match =~ s/雑がみは4日18日の金曜日です/雑がみは4日、18日の金曜日です/;
        $match =~ s/です。、雑がみは/です。雑がみは/;
        $match =~ s/です。がみは/です。雑がみは/;
        $match =~ s/です。雑雑がみは/です。雑がみは/;
        $match =~ s/雑がみは日、7日/雑がみは7日/;
        $match =~ s/枝・葉・草は1日、29の木曜日です/枝・葉・草は1日、29日の木曜日です/;
        $match =~ s/燃やせないごみは1日、29の水曜日です/燃やせないごみは1日、29日の水曜日です/;
        $match =~ s/燃やせないごみは1日、29日」の金曜日です/燃やせないごみは1日、29日の金曜日です/;
        $match =~ s/雑がみは12日、26の火曜日です/雑がみは12日、26日の火曜日です/;
        $match =~ s/４月枝・葉・草の収集はありません/４月は枝・葉・草の収集はありません/;
        $match =~ s/雑がみ3日、17日の火曜日です/雑がみは3日、17日の火曜日です/;
        $match =~ s/雑がみ3日、17日の水曜日です/雑がみは3日、17日の水曜日です/;
        $match =~ s/雑がみ14日、28日の水曜日です/雑がみは14日、28日の水曜日です/;
        $match =~ s/枝・葉・草は、7日の月曜日です/枝・葉・草は7日の月曜日です/;
        $match =~ s/枝・葉・草18日の水曜日です/枝・葉・草は18日の水曜日です/;

        if (!($match =~ m@平成(?<wa>[0-9]+?)年(?<mon>[0-9]+?)月@)) {
		    print "!!! $match\n";
            next;
		} else {
		    print ">>> $match\n";
		}


        my $year = $+{wa} + 1988; # 平成->西暦
        my $month = $+{mon}; # 月

        foreach (split '。', $match) {

            p $_;

            if (/^燃やせないごみは(\d+)日の\S+曜日です/) {
                push $ret->{'燃やせないごみ'}, date_format([ParseDate("$1 in $mon->{$month} $year")]);
            } elsif (/^燃やせないごみは(\d+)日、(\d+)日の\S+曜日です/) {
                push $ret->{'燃やせないごみ'}, date_format([ParseDate("$1 in $mon->{$month} $year")]);
                push $ret->{'燃やせないごみ'}, date_format([ParseDate("$2 in $mon->{$month} $year")]);

            } elsif (/^枝・葉・草は(\d+)日、(\d+)日の\S+曜日です/) {
                push $ret->{'枝・葉・草'}, date_format([ParseDate("$1 in $mon->{$month} $year")]);
                push $ret->{'枝・葉・草'}, date_format([ParseDate("$2 in $mon->{$month} $year")]);
            } elsif (/^枝・葉・草は(\d+)日の\S+曜日です/) {
                push $ret->{'枝・葉・草'}, date_format([ParseDate("$1 in $mon->{$month} $year")]);

            } elsif (/^びん・缶・ペットボトルは毎週(\S+?)曜日、容器包装プラスチックは毎週(\S+?)曜日です/) {
                push $ret->{'びん・缶・ペットボトル'}, date_format([ParseRecur("every $day->{$1} in $mon->{$month} $year")]);
                push $ret->{'容器包装プラスチック'}, date_format([ParseRecur("every $day->{$2} in $mon->{$month} $year")]);

            } elsif (/^雑がみは(\d+)日、(\d+)日の\S+曜日です/) {
                push $ret->{'雑がみ'}, date_format([ParseDate("$1 in $mon->{$month} $year")]);
                push $ret->{'雑がみ'}, date_format([ParseDate("$2 in $mon->{$month} $year")]);
            } elsif (/^雑がみは(\d+)日、(\d+)日、(\d+)日の\S+曜日です/) { # レア
                push $ret->{'雑がみ'}, date_format([ParseDate("$1 in $mon->{$month} $year")]);
                push $ret->{'雑がみ'}, date_format([ParseDate("$2 in $mon->{$month} $year")]);
                push $ret->{'雑がみ'}, date_format([ParseDate("$3 in $mon->{$month} $year")]);
            } elsif (/^雑がみは(\d+)日の\S+曜日です/) {
                push $ret->{'雑がみ'}, date_format([ParseDate("$1 in $mon->{$month} $year")]);

            } elsif (/^燃やせるごみは、毎週(\S+?)曜日と(\S+?)曜日です/) {
                push $ret->{'燃やせるごみ'}, date_format([ParseRecur("every $day->{$1} in $mon->{$month} $year")]);
                push $ret->{'燃やせるごみ'}, date_format([ParseRecur("every $day->{$2} in $mon->{$month} $year")]);
                @{$ret->{'燃やせるごみ'}} = sort @{$ret->{'燃やせるごみ'}}; # 順序が狂うのでソート

            } elsif (/^\S+月は枝・葉・草の収集はありません/) {
                # nothing
            } elsif (/^\S+月は燃やせないごみの収集はありません/) {
                # nothing
            } elsif (/^平成\d+年\d+月の収集日です/) {
                # nothing
            } else {
                return undef; # oh...
            }

        } # foreach
    } # foreach
    return $ret;
}

main();
