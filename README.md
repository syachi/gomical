SYNOPSIS
---------

```
$ scraping.pl
```

DESCRIPTION
---------

札幌市の「音声読み上げ用家庭ごみ収集日カレンダー」をクロールしてタブ区切りで出力します。  
ページを読みこむ度に10秒ずつsleepするので、結果が出るまで時間がかかります。

クロールするページの著作権については下記のURLの条件に従ってください。  
http://www.city.sapporo.jp/city/copyright/link.html

DEPENDENCIES
---------

* CHI
* WWW::Mechanize::Cached
