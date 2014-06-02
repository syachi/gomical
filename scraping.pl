#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use CHI;
use WWW::Mechanize::Cached;

binmode(STDOUT, ":utf8");
$|++;

my $interval = 10; # 秒

my $datastore = {};
my $cache = CHI->new(driver => 'Memory', datastore => $datastore); # memory cache
#my $cache = CHI->new(driver => 'File', root_dir => 'my_cache'); # file cache

# トップページを取得
my $w = WWW::Mechanize::Cached->new(autocheck => 0, cache => $cache);
$w->get('http://www.city.sapporo.jp/seiso/kaisyu/yomiage/index.html');

# トップページに含まれる区のリンク
my @wards = $w->find_all_links(url_regex => qr@/yomiage/[0-9]+.+\.html$@);
foreach my $ward (@wards) {

    # 区のページを取得
    sleep $interval if !$w->is_cached();
    $w->get($ward->url_abs());

    # 区のページに含まれる「通り」のリンクを抽出(同じページのリンクが複数含まれる)
    my @streets = $w->find_all_links(url_regex => qr@/carender/[0-9]+.+\.html$@);
    foreach my $street (@streets) {

        # 通りのページを取得
        sleep $interval if !$w->is_cached();
        $w->get($street->url_abs());

        # 文章を抽出(最後が<br />だったり</p>だったりする)
        my @matches = ($w->content() =~ m@(平成.+の収集日です。.*?)<.+?>@g);
        foreach my $match (@matches) {

            # タブ区切りで画面に出力する(区/通り/URL/西暦/月/文章)
            if ($match =~ m@平成(?<wa>[0-9]+?)年(?<mon>[0-9]+?)月@) {
                print join("\t", ($ward->text(), $street->text(), $street->url_abs, $+{wa} + 1988, $+{mon}, $match)) . "\n";
            } else {
                print "ummm..\n"; # 想定外の形式
            }
        }
    }
}
