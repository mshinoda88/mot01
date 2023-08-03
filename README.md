# YOLOX + bytetrack による物体トラッキングサンプル

## 出来ること
- YOLOXは高速物体検知が可能だが、bytetrackにより動画の中の物体に対してトラッキングIDを付与して、
 連続したトラッキングが可能になる

## 改良点
- 問題点：MSのバウンディングボックスライブラリが古い numpy(1.19以前) を参照しているライブラリなので、最新の numpy で動作しない。
- 具体的には numpy.float という古い型を参照していた。これは現在では float64 という型で代替可能。
- 最新の numpy で動作するよう実装を修正。さらにcpythonによる高速化ライブラリを準備

## 動作環境の準備
以下のコマンドでコンテナを作成。Dockerfile/requirements.txtを参照してコンテナを作成している。

```
$ bash ctrl-container.sh build
```

以下のコマンドでコンテナの起動、内部へログインが可能

```
$ bash ctrl-container.sh start
$ bash ctrl-container.sh login
```

## トラッキング結果動画の生成
コンテナの中で以下を実行

- 入力ファイル：XX.mp4
- 出力ファイル：XX_tracked.webm

```
(container)$ cd /usr/src/app/yolox-bytetrack-mcmot-sample
(container)$ bash exec01.sh
--movie ./test.mp4　のように、入力動画ファイルのパスを指定すると、
**_tracked.webm の名前の出力ファイルが作成される。
```

```exec01.sh
#!/bin/bash
date
python3 sample.py --movie ./test.mp4 --width 1280 --height 720 --yolox_model model/yolox_s.onnx --input_shape 640,640
#python3 sample.py --movie ./20220922-1220.mp4 --width 1280 --height 720 --yolox_model model/yolox_s.onnx --input_shape 640,640
date
```


