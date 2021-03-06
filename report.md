# レポート課題

> 1. スライスの分割・結合  
> スライスの分割と結合機能を追加する  
> 2. スライスの可視化  
> Graphvizでスライスの状態を表示

## 役割分担
* Sliceコマンド関連：@yamatchan, @k-nakahr
* Graphviz関連：@s-kojima, @sunya-ch
* レポート執筆：@yamatchan, @s-kojima
* ソーラン節：@s-sigaki

## コードの解説
### コマンドの追加
スライス結合機能・分割機能を追加するために，``bin/slice``に``split``および``join``コマンドを追加した．  
``Slice``クラスに``#split``メソッドおよび``#join``メソッドを実装したので，そのメソッドにそのまま丸投げするだけ．  
なお，結合および分割の内容は配布されたスライドの通り``into``オプションで指定するようにした．

### スライス結合機能
``Sliceクラス``に``#join``メソッドを追加した．  
``#join``メソッドの処理手順は以下の通りである．    
なお，不可分な一連の処理であるため，
入力エラーチェックと結合処理を完全に切り分け，
入力エラーチェック(1-5)を行ってから結合処理(6-7)を行うようにした．

1. ``into``オプションで指定された文字列を``,``で分割する  
2. その``,``で分割された文字列の前後の空白を削除する  
3. スライスが存在するかチェックをする．存在しなければ``SliceNotFoundError``を返す  
4. 結合スライスリストに当該スライス名を追加する  
5. 2-4を分割された文字列がなくなるまで繰り返す  
6. 結合スライスリストに重複があれば削除をする  
7. `s`オプションで指定されたスライスに結合処理を行う  


### スライス分割機能
``Sliceクラス``に``#split``メソッドを追加した．  
``#split``メソッドの処理手順は以下の通りである．   
スライス結合機能と同様に不可分な一連の処理であるため，
入力エラーチェックと結合処理を完全に切り分け，
入力エラーチェック(1-4)を行ってから結合処理(5-6)を行うようにした．

1. ``into``オプションで指定された文字列を`` ``(半角スペース)で分割する
2. 正規表現で``スライス名:ホスト群``の形式に一致しているかチェックする
3. 分割スライス名が既に存在していれば，``SliceAlreadyExistsError``を返す
4. ホスト群を``,``で分割し，それぞれのホスト名に対して存在処理を行う．``s``オプションで指定されたスライス(分割元スライス)当該ホストが存在していなければ``PortNotFoundError``を返す
5. それぞれの分割スライスに対して，スライスを作成する．
6. 作成したスライスにホストを追加し，分割元スライスからホストを削除する

※ ホスト群 = ホスト名{,ホスト名}

### スライス可視化機能
Graphviz導入部分に関しては，前回レポート([routing_switch](https://github.com/handai-trema/routing_switch-east/blob/master/report.md))を参照のこと．  
Graphvizクラスの``#generate_graph``メソッドにスライス可視化機能を追加した．  
スライスの可視化にはGraphvizのサブグラフ機能を利用した．  
ほとんど前回課題のコードを流量したので，
特に説明する部分はないが，サブグラフ名を``cluster.*``にしないとグラフに反映されない部分でハマった．  



## 動作確認
オリジナルの`trema.conf`を用いて，動作確認を行った，  
まず，全てのホストとスイッチのトポロジ画像を生成するために，以下のコマンドを実行した．

```
$ bin/trema run lib/routing_switch.rb -c trema.conf -- -s
$ bin/trema send_packet -s host1 -d host2
$ bin/trema send_packet -s host2 -d host1
$ bin/trema send_packet -s host3 -d host1
$ bin/trema send_packet -s host4 -d host1
```

上記コマンド実行後に出力されたトポロジ画像を以下に示す．  
![実行結果](./img/result1.png)

### スライス可視化機能
次に，スライスの可視化機能を確認するために，host1およびhost2をSliceAに追加，host3をSliceBに追加した．  
入力コマンドおよびコマンド実行後のトポロジ画像を以下に示す．  

```
$ bin/slice add SliceA
$ bin/slice add SliceB
$ bin/slice add_host -s SliceA --mac 11:11:11:11:11:11 --port 0x1:1
$ bin/slice add_host -s SliceA --mac 22:22:22:22:22:22 --port 0x2:1
$ bin/slice add_host -s SliceB --mac 33:33:33:33:33:33 --port 0x3:1
```

![実行結果](./img/result2.png)


### スライス結合機能
次に，スライスの結合機能の動作確認を行うために，SliceBをSliceAに結合する処理を行った．

まず，スライス結合機能の仕様を説明する．  
以下のコマンドを実行すると，sオプションに指定したスライスにintoオプションに指定したスライス(複数可)を結合する．  
なお，sオプションに指定したスライスが存在しない場合は，新たにスライスを作成し，intoオプションのスライスを結合する． 
また，結合されたスライスは削除される．

```
$ bin/slice join -s <slice-name> --into <slice-name>{,<slice-name>}
``` 
  
入力コマンドおよびコマンド実行後のトポロジ画像を以下に示す．  
画像かくにん！ よかった．(小保方風に)  

```
$ bin/slice join -s SliceA --into SliceB
$ bin/slice list
SliceA
  0x1:1
    11:11:11:11:11:11
  0x2:1
    22:22:22:22:22:22
  0x3:1
    33:33:33:33:33:33
```

![実行結果](./img/result3.png)


### スライス分割機能
次に，スライスの分割機能の動作確認を行うために，host4をSliceAに追加した後に，SliceBをSliceAに結合する処理を行った．
sオプションに指定したスライドをintoオプションに指定した通りに分割を行う．  
なお，分割に指定されなかったホストは，そのままsオプションのスライスに残すようにした．  
動作確認にあたり入力コマンドおよびコマンド実行後のトポロジ画像を以下に示す． 

```
$ bin/slice add_host -s SliceA --mac 44:44:44:44:44:44 --port 0x4:1
$ bin/slice split -s SliceA --into "SliceB:0x2:1 SliceC:0x3:1,0x4:1"
$ bin/slice list
SliceA
  0x1:1
    11:11:11:11:11:11
SliceB
  0x2:1
    22:22:22:22:22:22
SliceC
  0x3:1
    33:33:33:33:33:33
  0x4:1
    44:44:44:44:44:44
```

![実行結果](./img/result4.png)


終わりなんだ(*^◯^*)
