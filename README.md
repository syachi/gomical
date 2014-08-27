SYNOPSIS
---------

```
$ script/to_csv.pl
$ script/to_json.pl
$ PORT=3000 Perloku
```

DESCRIPTION
---------

これはHokkaido.pm casualのお題で制作したツールです。

札幌市の「音声読み上げ用家庭ごみ収集日カレンダー」をクロールしてタブ区切りで出力します。  
ページを読みこむ度に10秒ずつsleepするので、結果が出るまで時間がかかります。

クロールするページの著作権については下記のURLの条件に従ってください。  
http://www.city.sapporo.jp/city/copyright/link.html



* script/to_csv.pl
  csv形式でごみカレンダーを出力します。

* script/to_json.pl
  json形式でごみカレンダーを出力します。

* script/to_gomical.pl
  gomical用の形式でごみカレンダーを出力します。

DEPENDENCIES
---------

* CHI
* WWW::Mechanize::Cached
* Date::Manip
* JSON
* Mojolicious
* Data::ICal
